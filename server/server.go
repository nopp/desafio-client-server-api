package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
)

const (
	urlBase     = "https://economia.awesomeapi.com.br/json/last/USD-BRL"
	createTable = `CREATE TABLE IF NOT EXISTS coin (
		id VARCHAR(255) PRIMARY KEY,
		code VARCHAR(255),
		codein VARCHAR(255),
		name VARCHAR(255),
		varbid VARCHAR(255),
		bid VARCHAR(255)
	);`
)

type infoExchange struct {
	USDBRL struct {
		ID     string `json:"id"`
		Code   string `json:"code"`
		Codein string `json:"codein"`
		Name   string `json:"name"`
		VarBid string `json:"varBid"`
		Bid    string `json:"bid"`
	}
}

func connectDB() (*sql.DB, error) {
	db, err := sql.Open("sqlite3", "./server.db")
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(createTable); err != nil {
		return nil, err
	}

	return db, nil
}

func getExchange(w http.ResponseWriter, r *http.Request) {

	var info infoExchange

	// Little hammer to ignore favicons logs
	if r.URL.Path == "/favicon.ico" {
		http.NotFound(w, r)
		return
	}

	// Connect to the database
	db, err := connectDB()
	if err != nil {
		log.Println(err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer db.Close()

	// Create a context with a timeout of 200 milliseconds
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)

	defer cancel()

	// Make GET to the urlBase using the context
	req, err := http.NewRequestWithContext(ctx, "GET", urlBase, nil)

	if err != nil {
		if err == context.DeadlineExceeded {
			log.Println(err.Error())
		}
		log.Println(err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Read bytes to string
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		log.Println(err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// String to JSON
	json.Unmarshal(body, &info)

	// Create a context with a timeout of 10 milliseconds
	ctxDB, cancelDB := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancelDB()

	stmt, err := db.PrepareContext(ctxDB, "INSERT INTO coin (id, code, codein, name, varbid, bid) VALUES (?, ?, ?, ?, ?, ?)")
	if err != nil {
		if err == context.DeadlineExceeded {
			log.Println(err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	}
	defer stmt.Close()
	_, err = stmt.ExecContext(ctxDB, uuid.New().String(), info.USDBRL.Code, info.USDBRL.Codein, info.USDBRL.Name, info.USDBRL.VarBid, info.USDBRL.Bid)
	if err != nil {
		if err == context.DeadlineExceeded {
			log.Println(err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	}
	// Return the bid value as JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info.USDBRL.Bid)
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/cotacao", getExchange)
	http.ListenAndServe(":8080", mux)
}
