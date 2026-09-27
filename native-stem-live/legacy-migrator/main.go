package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/chromedp/cdproto/browser"
	"github.com/chromedp/cdproto/runtime"
	"github.com/chromedp/chromedp"
)

type exportManifest struct {
	Songs []json.RawMessage `json:"songs"`
	Stems []struct {
		DownloadName string `json:"downloadName"`
	} `json:"stems"`
}

func main() {
	profile := flag.String("profile", "", "legacy Chrome profile")
	html := flag.String("html", "", "legacy STEM Live index.html")
	out := flag.String("out", "", "migration output directory")
	flag.Parse()

	if *profile == "" || *html == "" || *out == "" {
		fail("profile, html and out are required")
	}
	if _, err := os.Stat(*profile); err != nil {
		fail("Legacy Chrome profile not found: " + err.Error())
	}
	if _, err := os.Stat(*html); err != nil {
		fail("Legacy STEM Live app not found: " + err.Error())
	}

	if p := exec.Command("/usr/bin/pgrep", "-f", *profile); p.Run() == nil {
		fail("Close the old STEM Live Alpha completely before migration, then try again.")
	}

	chrome := locateChrome()
	if chrome == "" {
		fail("Google Chrome is required only for this one-time Legacy Alpha migration.")
	}

	if err := os.RemoveAll(*out); err != nil {
		fail(err.Error())
	}
	if err := os.MkdirAll(*out, 0755); err != nil {
		fail(err.Error())
	}

	fmt.Println("PREPARING safe copy of legacy Chrome profile")
	profileCopy := filepath.Join(*out, "LegacyChromeProfile")
	if err := run("/usr/bin/ditto", *profile, profileCopy); err != nil {
		fail("Could not copy Legacy Alpha storage safely: " + err.Error())
	}

	fileURL := (&url.URL{Scheme: "file", Path: *html}).String()
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.ExecPath(chrome),
		chromedp.UserDataDir(profileCopy),
		chromedp.Flag("headless", true),
		chromedp.Flag("no-first-run", true),
		chromedp.Flag("disable-default-apps", true),
		chromedp.Flag("disable-background-networking", true),
		chromedp.Flag("disable-sync", true),
		chromedp.Flag("allow-file-access-from-files", true),
	)

	allocCtx, cancelAlloc := chromedp.NewExecAllocator(context.Background(), opts...)
	defer cancelAlloc()
	ctx, cancel := chromedp.NewContext(allocCtx)
	defer cancel()

	ctx, timeoutCancel := context.WithTimeout(ctx, 20*time.Minute)
	defer timeoutCancel()

	fmt.Println("EXPORTING Legacy Alpha IndexedDB songs and stem blobs")
	js := migrationJS()

	err := chromedp.Run(ctx,
		chromedp.ActionFunc(func(ctx context.Context) error {
			return browser.SetDownloadBehavior(browser.SetDownloadBehaviorBehaviorAllow).
				WithDownloadPath(*out).
				WithEventsEnabled(true).
				Do(ctx)
		}),
		chromedp.Navigate(fileURL),
		chromedp.WaitReady("body", chromedp.ByQuery),
		chromedp.Sleep(900*time.Millisecond),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, exception, err := runtime.Evaluate(js).
				WithAwaitPromise(true).
				WithReturnByValue(false).
				Do(ctx)
			if err != nil {
				return err
			}
			if exception != nil {
				return fmt.Errorf("legacy page script exception")
			}
			return nil
		}),
	)
	if err != nil {
		fail("Could not read the Legacy Alpha database: " + err.Error())
	}

	manifest, err := waitForManifest(*out, 30*time.Second)
	if err != nil {
		fail(err.Error())
	}
	fmt.Printf("EXPORTING %d song(s), %d stem blob(s)\n", len(manifest.Songs), len(manifest.Stems))
	if err := waitForDownloads(*out, manifest, 15*time.Minute); err != nil {
		fail(err.Error())
	}

	_ = os.RemoveAll(profileCopy)
	fmt.Printf("DONE %d song(s) and %d stem(s) exported\n", len(manifest.Songs), len(manifest.Stems))
}

func locateChrome() string {
	home, _ := os.UserHomeDir()
	candidates := []string{
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
		filepath.Join(home, "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
	}
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func waitForManifest(dir string, timeout time.Duration) (exportManifest, error) {
	deadline := time.Now().Add(timeout)
	path := filepath.Join(dir, "migration_manifest.json")
	for time.Now().Before(deadline) {
		data, err := os.ReadFile(path)
		if err == nil && len(data) > 0 {
			var manifest exportManifest
			if json.Unmarshal(data, &manifest) == nil {
				return manifest, nil
			}
		}
		time.Sleep(200 * time.Millisecond)
	}
	return exportManifest{}, fmt.Errorf("Legacy manifest was not produced by Chrome")
}

func waitForDownloads(dir string, manifest exportManifest, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	required := []string{"migration_manifest.json"}
	for _, stem := range manifest.Stems {
		required = append(required, stem.DownloadName)
	}
	for time.Now().Before(deadline) {
		all := true
		for _, name := range required {
			st, err := os.Stat(filepath.Join(dir, name))
			if err != nil || st.Size() == 0 {
				all = false
				break
			}
		}
		if all {
			matches, _ := filepath.Glob(filepath.Join(dir, "*.crdownload"))
			if len(matches) == 0 {
				return nil
			}
		}
		time.Sleep(350 * time.Millisecond)
	}
	return fmt.Errorf("Legacy export timed out while waiting for embedded stem audio to finish downloading")
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, "ERROR:", message)
	os.Exit(1)
}

func migrationJS() string {
	script := `(async () => {
	  const openDB = () => new Promise((resolve, reject) => {
	    const req = indexedDB.open('StemLiveDB', 1);
	    req.onsuccess = () => resolve(req.result);
	    req.onerror = () => reject(req.error || new Error('IndexedDB open failed'));
	  });
	  const all = (db, store) => new Promise((resolve, reject) => {
	    const tx = db.transaction(store, 'readonly');
	    const req = tx.objectStore(store).getAll();
	    req.onsuccess = () => resolve(req.result || []);
	    req.onerror = () => reject(req.error || new Error('Read failed: ' + store));
	  });
	  const clean = (s) => String(s || 'stem').replace(/[\\/:?%*|"<>]/g, '_').replace(/\s+/g, ' ').trim() || 'stem';
	  const delay = (ms) => new Promise(r => setTimeout(r, ms));
	  const download = async (blob, name) => {
	    const a = document.createElement('a');
	    const u = URL.createObjectURL(blob);
	    a.href = u;
	    a.download = name;
	    a.style.display = 'none';
	    document.body.appendChild(a);
	    a.click();
	    await delay(150);
	    a.remove();
	    setTimeout(() => URL.revokeObjectURL(u), 15000);
	  };

	  const db = await openDB();
	  const songs = await all(db, 'songs');
	  const rows = await all(db, 'stems');
	  const stems = rows.map(r => {
	    const name = r.name || 'stem.wav';
	    const extMatch = String(name).match(/(\.[A-Za-z0-9]{1,8})$/);
	    const ext = extMatch ? extMatch[1] : '';
	    const base = ext ? String(name).slice(0, -ext.length) : String(name);
	    const downloadName = 'stem_' + clean(r.songId) + '__' + clean(r.id) + '__' + clean(base) + ext;
	    return {
	      id: r.id,
	      songId: r.songId,
	      name,
	      size: r.size || (r.blob ? r.blob.size : 0),
	      type: r.type || (r.blob ? r.blob.type : ''),
	      downloadName
	    };
	  });

	  const manifest = { version: 2, exportedAt: new Date().toISOString(), songs, stems };
	  await download(new Blob([JSON.stringify(manifest, null, 2)], {type:'application/json'}), 'migration_manifest.json');

	  const downloads = [];
	  for (let i = 0; i < rows.length; i++) {
	    const row = rows[i];
	    const meta = stems[i];
	    if (row && row.blob instanceof Blob) {
	      await download(row.blob, meta.downloadName);
	      downloads.push(meta.downloadName);
	    }
	  }

	  return { songs: songs.length, stems: downloads.length, downloads };
	})()`
	return strings.TrimSpace(script)
}
