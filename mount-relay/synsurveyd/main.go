package main

import (
	"encoding/hex"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"time"
)

const (
	mount     = "192.168.4.1:11880"
	stopFile  = "/data/local/tmp/survey.stop"
	CtsPerDeg = 16777216.0 / 360.0
)

var conn net.Conn
var errStopped = fmt.Errorf("stopped")

func dial() {
	if c, err := net.Dial("udp", mount); err == nil {
		conn = c
	}
}

func cmd(s string) (string, error) {
	if conn == nil { dial() }
	for attempt := 0; attempt < 3; attempt++ {
		conn.SetReadDeadline(time.Now().Add(1500 * time.Millisecond))
		if _, err := conn.Write([]byte(s + "\r")); err != nil {
			dial()
			continue
		}
		buf := make([]byte, 64)
		n, err := conn.Read(buf)
		if err != nil {
			time.Sleep(120 * time.Millisecond)
			continue
		}
		r := strings.Trim(strings.TrimSpace(string(buf[:n])), "\r\n ")
		if strings.HasPrefix(r, "!") {
			return "", fmt.Errorf("%q -> %s", s, r)
		}
		return strings.TrimPrefix(r, "="), nil
	}
	return "", fmt.Errorf("%q no-reply", s)
}

func wrap180(v float64) float64 {
	for v > 180 { v -= 360 }
	for v <= -180 { v += 360 }
	return v
}

func rawPos(axis int) (float64, error) {
	r, err := cmd(fmt.Sprintf(":j%d", axis))
	if err != nil { return 0, err }
	b, err := hex.DecodeString(r)
	if err != nil || len(b) != 3 { return 0, fmt.Errorf("bad pos %q", r) }
	v := int64(b[0])<<16 | int64(b[1])<<8 | int64(b[2])
	if v > 0x7FFFFF { v -= 0x1000000 }
	return float64(v), nil
}

var spd = [3]string{"", "200000", "200000"}
var errBad = fmt.Errorf("bad")

func checkStop() error {
	if _, err := os.Stat(stopFile); err == nil { return errStopped }
	return nil
}

// slew BOTH axes at once; targets are degrees relative to (o1,o2)
func moveBoth(o1, o2, ra, dec float64) error {
	s1, err1 := rawPos(1)
	s2, err2 := rawPos(2)
	if err1 != nil || err2 != nil { return errBad }
	d1 := ra - wrap180(s1-o1)
	d2 := dec - wrap180(s2-o2)
	if err := checkStop(); err != nil { return errStopped }

	start := func(axis int, d float64) bool {
		if d == 0 { return true } // already there
		dir := "0"
		if d < 0 { dir = "1" }
		cmd(fmt.Sprintf(":K%d", axis))
		if _, err := cmd(fmt.Sprintf(":G%d3%s", axis, dir)); err != nil { return false }
		if _, err := cmd(fmt.Sprintf(":I%d%s", axis, spd[axis])); err != nil { return false }
		_, err := cmd(fmt.Sprintf(":J%d", axis))
		return err == nil
	}
	a1 := start(1, d1)
	a2 := start(2, d2)
	if !a1 { log.Printf("ax1 start failed") }
	if !a2 { log.Printf("ax2 start failed") }

	arrived := func(axis int, startRaw, d float64) bool {
		p, err := rawPos(axis)
		if err != nil { return false }
		traveled := wrap180(p - startRaw)
		if d >= 0 {
			return traveled >= d-0.3
		}
		return traveled <= d+0.3
	}

	t0 := time.Now()
	for i := 0; i < 800 && (!a1 || !a2); i++ {
		if err := checkStop(); err != nil {
			cmd(":K1"); cmd(":K2")
			return errStopped
		}
		time.Sleep(100 * time.Millisecond)
		if !a1 && arrived(1, s1, d1) { cmd(":K1"); a1 = true; log.Printf("ax1 done @%s", time.Since(t0).Truncate(time.Millisecond)) }
		if !a2 && arrived(2, s2, d2) { cmd(":K2"); a2 = true; log.Printf("ax2 done @%s", time.Since(t0).Truncate(time.Millisecond)) }
	}
	if !a1 { cmd(":K1"); log.Printf("ax1 TIMEOUT") }
	if !a2 { cmd(":K2"); log.Printf("ax2 TIMEOUT") }
	return nil
}

func main() {
	log.SetFlags(log.Ltime)
	if f, err := os.OpenFile("/data/local/tmp/survey.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644); err == nil {
		log.SetOutput(f)
	}
	log.Printf("=== survey v2: simultaneous, RA90/DEC60 steps ===")
	o1, err := rawPos(1)
	if err != nil { log.Fatal(err) }
	o2, err := rawPos(2)
	if err != nil { log.Fatal(err) }
	log.Printf("origin=(%.0f,%.0f)", o1, o2)

	raPts := []float64{-90, 0, 90, 0, -90, 0, 90}
	decPts := []float64{-60, -60, -60, 0, 60, 60, 60}
	stopped := false
	for i := range raPts {
		if err := checkStop(); err != nil { stopped = true; break }
		log.Printf("pt %d/7 RA%+.0f DEC%+.0f", i+1, raPts[i], decPts[i])
		t0 := time.Now()
		if err := moveBoth(o1, o2, raPts[i], decPts[i]); err == errStopped { stopped = true; break }
		if w := 10*time.Second - time.Since(t0); w > 0 { time.Sleep(w) }
	}
	if err := checkStop(); err == nil && !stopped {
		log.Printf("homing")
		moveBoth(o1, o2, 0, 0)
		log.Printf("=== done, at origin ===")
	} else {
		cmd(":K1"); cmd(":K2")
		log.Printf("=== stopped by user ===")
	}
	os.Remove(stopFile)
}
