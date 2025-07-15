# Variáveis
SERVER_DIR = server
CLIENT_DIR = client
SERVER_BIN = $(SERVER_DIR)/server
CLIENT_BIN = $(CLIENT_DIR)/client
SERVER_PID_FILE = server.pid
SERVER_PORT = 8080

# Cores para output
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help build build-server build-client run-server stop-server run-client clean deps test status all kill-server test-server wait-for-server demo test-server

# Target padrão
all: deps build

# Ajuda
help:
	@echo "$(GREEN)Comandos disponíveis:$(NC)"
	@echo "  $(YELLOW)make help$(NC)         - Mostra esta ajuda"
	@echo "  $(YELLOW)make deps$(NC)         - Instala dependências"
	@echo "  $(YELLOW)make build$(NC)        - Builda server e client"
	@echo "  $(YELLOW)make build-server$(NC) - Builda apenas o server"
	@echo "  $(YELLOW)make build-client$(NC) - Builda apenas o client"
	@echo "  $(YELLOW)make run-server$(NC)   - Inicia o server em background"
	@echo "  $(YELLOW)make stop-server$(NC)  - Para o server"
	@echo "  $(YELLOW)make kill-server$(NC)  - Força parada de todos os processos server"
	@echo "  $(YELLOW)make run-client$(NC)   - Executa o client"
	@echo "  $(YELLOW)make test-server$(NC)  - Testa conectividade com o server"
	@echo "  $(YELLOW)make status$(NC)       - Verifica status do server"
	@echo "  $(YELLOW)make test$(NC)         - Executa testes"
	@echo "  $(YELLOW)make clean$(NC)        - Remove arquivos gerados"
	@echo "  $(YELLOW)make all$(NC)          - Instala deps e builda tudo"

# Instalar dependências
deps:
	@echo "$(GREEN)Instalando dependências...$(NC)"
	cd $(SERVER_DIR) && go mod tidy
	cd $(CLIENT_DIR) && go mod tidy

# Build de ambos
build: build-server build-client

# Build do server
build-server:
	@echo "$(GREEN)Buildando server...$(NC)"
	cd $(SERVER_DIR) && go build -o server server.go

# Build do client
build-client:
	@echo "$(GREEN)Buildando client...$(NC)"
	cd $(CLIENT_DIR) && go build -o client client.go

# Executar server em background
run-server: build-server stop-server
	@echo "$(GREEN)Iniciando server na porta $(SERVER_PORT)...$(NC)"
	@nohup $(SHELL) -c "cd $(SERVER_DIR) && ./server" > /dev/null 2>&1 & echo $$! > $(SERVER_PID_FILE)
	@sleep 3
	@if [ -f $(SERVER_PID_FILE) ]; then \
		PID=$$(cat $(SERVER_PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo "$(GREEN)Server iniciado com PID: $$PID$(NC)"; \
			echo "$(GREEN)Aguarde alguns segundos para o server estar pronto...$(NC)"; \
		else \
			echo "$(RED)Processo não está rodando$(NC)"; \
			rm -f $(SERVER_PID_FILE); \
			exit 1; \
		fi; \
	else \
		echo "$(RED)Erro ao criar arquivo PID$(NC)"; \
		exit 1; \
	fi

# Parar server
stop-server:
	@if [ -f $(SERVER_PID_FILE) ]; then \
		PID=`cat $(SERVER_PID_FILE)`; \
		if kill -0 $$PID 2>/dev/null; then \
			echo "$(YELLOW)Parando server (PID: $$PID)...$(NC)"; \
			kill $$PID; \
			rm -f $(SERVER_PID_FILE); \
			echo "$(GREEN)Server parado com sucesso$(NC)"; \
		else \
			echo "$(YELLOW)Server não estava rodando$(NC)"; \
			rm -f $(SERVER_PID_FILE); \
		fi \
	else \
		echo "$(YELLOW)Arquivo PID não encontrado, verificando processos órfãos...$(NC)"; \
	fi
	@pkill -f "./server" 2>/dev/null || true
	@sleep 1

# Forçar parada de todos os processos server
kill-server:
	@echo "$(YELLOW)Forçando parada de todos os processos server...$(NC)"
	@pkill -f "server/server" 2>/dev/null || true
	@pkill -f "./server" 2>/dev/null || true
	@pkill -f "go run.*server.go" 2>/dev/null || true
	@lsof -ti:$(SERVER_PORT) | xargs kill -9 2>/dev/null || true
	@rm -f $(SERVER_PID_FILE)
	@rm -f start_server.sh
	@sleep 1
	@echo "$(GREEN)Todos os processos server foram finalizados$(NC)"

# Executar client
run-client: build-client
	@echo "$(GREEN)Executando client...$(NC)"
	@SERVER_RUNNING=false; \
	if [ -f $(SERVER_PID_FILE) ] && kill -0 `cat $(SERVER_PID_FILE)` 2>/dev/null; then \
		SERVER_RUNNING=true; \
	elif lsof -ti:$(SERVER_PORT) >/dev/null 2>&1; then \
		echo "$(YELLOW)Server detectado rodando na porta $(SERVER_PORT)$(NC)"; \
		SERVER_RUNNING=true; \
	elif pgrep -f "./server" >/dev/null 2>&1; then \
		echo "$(YELLOW)Processo server detectado$(NC)"; \
		SERVER_RUNNING=true; \
	fi; \
	if [ "$$SERVER_RUNNING" = "false" ]; then \
		echo "$(RED)ATENÇÃO: Server não está rodando. Execute 'make run-server' primeiro$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Aguardando server estar pronto...$(NC)"
	@sleep 2
	cd $(CLIENT_DIR) && ./client
	@if [ -f $(CLIENT_DIR)/cotacao.txt ]; then \
		echo "$(GREEN)Client executado com sucesso! Arquivo cotacao.txt criado:$(NC)"; \
		cat $(CLIENT_DIR)/cotacao.txt; \
	fi

# Aguardar server estar pronto
wait-for-server:
	@echo "$(GREEN)Aguardando server estar pronto...$(NC)"
	@for i in $$(seq 1 10); do \
		if curl -s -f http://localhost:$(SERVER_PORT)/cotacao >/dev/null 2>&1; then \
			echo "$(GREEN)Server está pronto!$(NC)"; \
			exit 0; \
		fi; \
		echo "$(YELLOW)Tentativa $$i/10 - aguardando...$(NC)"; \
		sleep 2; \
	done; \
	echo "$(RED)Timeout: Server não respondeu em 20 segundos$(NC)"; \
	exit 1

# Testar conectividade com o server
test-server:
	@echo "$(GREEN)Testando conectividade com o server...$(NC)"
	@if curl -s -f http://localhost:$(SERVER_PORT)/cotacao >/dev/null 2>&1; then \
		echo "$(GREEN)Server está respondendo na porta $(SERVER_PORT)$(NC)"; \
	else \
		echo "$(RED)Server não está respondendo$(NC)"; \
		exit 1; \
	fi

# Verificar status do server
status:
	@if [ -f $(SERVER_PID_FILE) ]; then \
		PID=`cat $(SERVER_PID_FILE)`; \
		if kill -0 $$PID 2>/dev/null; then \
			echo "$(GREEN)Server está rodando (PID: $$PID)$(NC)"; \
			echo "$(GREEN)Porta: $(SERVER_PORT)$(NC)"; \
			echo "$(GREEN)URL: http://localhost:$(SERVER_PORT)/cotacao$(NC)"; \
		else \
			echo "$(RED)Server PID não está ativo$(NC)"; \
			rm -f $(SERVER_PID_FILE); \
		fi \
	else \
		echo "$(YELLOW)Arquivo PID não encontrado$(NC)"; \
	fi
	@PORT_PID=$$(lsof -ti:$(SERVER_PORT) 2>/dev/null || true); \
	ORPHAN_PIDS=$$(pgrep -f "./server" 2>/dev/null || true); \
	if [ ! -z "$$PORT_PID" ]; then \
		echo "$(YELLOW)Processo usando porta $(SERVER_PORT): $$PORT_PID$(NC)"; \
		ps -p $$PORT_PID -o pid,ppid,command 2>/dev/null || true; \
	fi; \
	if [ ! -z "$$ORPHAN_PIDS" ]; then \
		echo "$(YELLOW)Processos órfãos detectados:$(NC)"; \
		ps -p $$ORPHAN_PIDS -o pid,ppid,command 2>/dev/null || true; \
		echo "$(YELLOW)Use 'make kill-server' para removê-los$(NC)"; \
	elif [ ! -f $(SERVER_PID_FILE) ] && [ -z "$$PORT_PID" ]; then \
		echo "$(RED)Nenhum processo server encontrado$(NC)"; \
	fi

# Executar testes
test:
	@echo "$(GREEN)Executando testes do server...$(NC)"
	cd $(SERVER_DIR) && go test -v ./...
	@echo "$(GREEN)Executando testes do client...$(NC)"
	cd $(CLIENT_DIR) && go test -v ./...

# Limpar arquivos gerados
clean: stop-server
	@echo "$(GREEN)Limpando arquivos gerados...$(NC)"
	rm -f $(SERVER_BIN) $(CLIENT_BIN)
	rm -f $(SERVER_PID_FILE)
	rm -f $(SERVER_DIR)/server.db
	rm -f $(CLIENT_DIR)/cotacao.txt
	rm -f start_server.sh
	@echo "$(GREEN)Limpeza concluída$(NC)"

# Target para rodar um fluxo completo: server + client
demo: run-server wait-for-server run-client
