package main

import (
	_ "embed"
	"encoding/hex"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

//go:embed pad.html
var padHTML string

var (
	conn   net.Conn
	cmu    sync.Mutex
	spdMap = map[string]string{"slow": "600000", "mid": "200000", "fast": "60000"}
	speed  = "200000"
	mu     sync.Mutex
	// held axes state
	held   = map[int]time.Time{} // axis -> press time
	signOf = map[int]int{}       // learned dir->counts sign per axis
)

func dial() {
	c, err := net.Dial("udp", "192.168.4.1:11880")
	if err != nil { log.Println(err); return }
	conn = c
}

func cmd(s string) string {
	cmu.Lock()
	defer cmu.Unlock()
	if conn == nil { dial(); if conn == nil { return "!" } }
	for i := 0; i < 2; i++ {
		conn.SetReadDeadline(time.Now().Add(1200 * time.Millisecond))
		conn.Write([]byte(s + "\r"))
		buf := make([]byte, 64)
		n, err := conn.Read(buf)
		if err != nil { dial(); continue }
		return strings.TrimSpace(string(buf[:n]))
	}
	return "!"
}

func pos(axis int) int64 {
	r := cmd(fmt.Sprintf(":j%d", axis))
	r = strings.TrimPrefix(r, "=")
	b, err := hex.DecodeString(r)
	if err != nil || len(b) != 3 { return 0 }
	v := int64(b[0])<<16 | int64(b[1])<<8 | int64(b[2])
	if v > 0x7FFFFF { v -= 0x1000000 }
	return v
}

// start slewing axis in dir; learn & enforce DEC soft limits
func press(axis int, dir string) string {
	mu.Lock()
	speed = spdMap[spdCur]
	mu.Unlock()
	if t, ok := held[axis]; ok && time.Since(t) < time.Minute {
		return "held" // already moving
	}
	before := pos(axis)
	cmd(fmt.Sprintf(":K%d", axis))
	cmd(fmt.Sprintf(":G%d3%s", axis, dir))
	cmd(fmt.Sprintf(":I%d%s", axis, speed))
	r := cmd(fmt.Sprintf(":J%d", axis))
	if !strings.HasPrefix(r, "=") { return r }
	held[axis] = time.Now()
	// learn direction sign (which way counts move) after 300ms
	time.Sleep(300 * time.Millisecond)
	after := pos(axis)
	d := after - before
	if d != 0 {
		s := int64(1)
		if d < 0 { s = -1 }
		_ = s
		signOf[axis] = int(s)
		if dir == "1" { signOf[axis] = -signOf[axis] }
	}
	// DEC soft limits from file "min max" (raw counts)
	if axis == 2 {
		if b, err := os.ReadFile("/data/local/tmp/declimits"); err == nil {
			var lo, hi int64
			fmt.Sscanf(string(b), "%d %d", &lo, &hi)
			cur := pos(2)
			mv := signOf[2]
			if dir == "1" { mv = -mv }
			if mv != 0 {
				if (mv < 0 && cur <= lo) || (mv > 0 && cur >= hi) {
					cmd(":K2")
					delete(held, 2)
					return "LIMIT"
				}
			}
		}
	}
	// auto-release watchdog
	go func(a int) {
		time.Sleep(15 * time.Second)
		mu.Lock()
		t, ok := held[a]
		mu.Unlock()
		if ok && time.Since(t) >= 15*time.Second {
			cmd(fmt.Sprintf(":K%d", a))
			mu.Lock(); delete(held, a); mu.Unlock()
		}
	}(axis)
	return "ok"
}

func release(axis int) string {
	cmd(fmt.Sprintf(":K%d", axis))
	mu.Lock(); delete(held, axis); mu.Unlock()
	return "ok"
}

var spdCur = "mid"

func main() {
	log.SetOutput(os.Stderr)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(padHTML)) })
	http.HandleFunc("/press", func(w http.ResponseWriter, r *http.Request) {
		var axis int
		fmt.Sscanf(r.URL.Query().Get("axis"), "%d", &axis)
		w.Write([]byte(press(axis, r.URL.Query().Get("dir"))))
	})
	http.HandleFunc("/release", func(w http.ResponseWriter, r *http.Request) {
		var axis int
		fmt.Sscanf(r.URL.Query().Get("axis"), "%d", &axis)
		w.Write([]byte(release(axis)))
	})
	http.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		cmd(":K1"); cmd(":K2")
		mu.Lock(); held = map[int]time.Time{}; mu.Unlock()
		w.Write([]byte("ok"))
	})
	http.HandleFunc("/speed", func(w http.ResponseWriter, r *http.Request) {
		s := r.URL.Query().Get("s")
		if _, ok := spdMap[s]; ok { spdCur = s }
		w.Write([]byte(spdCur))
	})
	http.HandleFunc("/pos", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%d %d", pos(1), pos(2))
	})
	http.HandleFunc("/setlimit", func(w http.ResponseWriter, r *http.Request) {
		which := r.URL.Query().Get("w")
		cur := pos(2)
		var lo, hi int64
		if b, err := os.ReadFile("/data/local/tmp/declimits"); err == nil {
			fmt.Sscanf(string(b), "%d %d", &lo, &hi)
		} else { lo, hi = -8388608, 8388607 }
		if which == "lo" { lo = cur } else { hi = cur }
		os.WriteFile("/data/local/tmp/declimits", []byte(fmt.Sprintf("%d %d", lo, hi)), 0644)
		fmt.Fprintf(w, "%d %d", lo, hi)
	})
	dial()
	log.Fatal(http.ListenAndServe("0.0.0.0:8080", nil))
}
