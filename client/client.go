package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

const (
	urlServer = "http://localhost:8080/cotacao"
)

func main() {

	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)

	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", urlServer, nil)

	if err != nil {
		if err == context.DeadlineExceeded {
			log.Println(err.Error())
		}
		log.Println(err.Error())
		return
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err.Error())
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err.Error())
		return
	}

	file, err := os.Create("cotacao.txt")
	if err != nil {
		log.Println(err.Error())
		return
	}
	defer file.Close()
	_, err = file.WriteString("Dólar: " + string(body))
	if err != nil {
		log.Println(err.Error())
		return
	}

}
