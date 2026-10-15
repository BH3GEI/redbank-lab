package main

import (
	"bufio"
	"log"
	"net"
	"os"
	"time"
)

const (
	listenAddr = "0.0.0.0:11881"
	mountAddr  = "192.168.4.1:11880"
)

func handle(c net.Conn) {
	defer c.Close()
	c.SetDeadline(time.Now().Add(5 * time.Second))
	line, err := bufio.NewReader(c).ReadString('\n')
	if err != nil {
		return
	}
	// strip \n, ensure \r
	cmd := []byte(line[:len(line)-1] + "\r")
	u, err := net.DialTimeout("udp", mountAddr, 2*time.Second)
	if err != nil {
		c.Write([]byte("!relay-dial\r"))
		return
	}
	defer u.Close()
	u.SetDeadline(time.Now().Add(4 * time.Second))
	if _, err := u.Write(cmd); err != nil {
		c.Write([]byte("!relay-write\r"))
		return
	}
	buf := make([]byte, 128)
	n, err := u.Read(buf)
	if err != nil {
		c.Write([]byte("!mount-timeout\r"))
		return
	}
	c.Write(buf[:n])
	log.Printf("cmd %q -> %q", string(cmd), string(buf[:n]))
}

func main() {
	log.SetOutput(os.Stderr)
	l, err := net.Listen("tcp", listenAddr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("synrelayd listening %s -> udp %s", listenAddr, mountAddr)
	for {
		c, err := l.Accept()
		if err != nil {
			time.Sleep(200 * time.Millisecond)
			continue
		}
		go handle(c)
	}
}
