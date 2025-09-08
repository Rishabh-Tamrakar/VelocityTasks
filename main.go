package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rishabh-tamrakar/velocitytasks/internal/api"
	"github.com/rishabh-tamrakar/velocitytasks/internal/storage"
)

func main() {
	// Get configuration from environment variables
	port := getEnv("PORT", "8080")
	host := getEnv("HOST", "0.0.0.0")
	staticDir := getEnv("STATIC_DIR", "web")
	maxTasks := getEnvInt("MAX_TASKS", 10000)

	// Initialize storage
	persistence := &storage.PersistenceConfig{
		Enabled:  getEnvBool("ENABLE_PERSISTENCE", false),
		FilePath: getEnv("PERSISTENCE_FILE", "tasks.json"),
	}

	taskStorage := storage.NewMemoryStorage(maxTasks, persistence)

	// Initialize API server
	apiServer := api.NewServer(taskStorage, staticDir)

	// Create HTTP server
	mux := http.NewServeMux()
	apiServer.SetupRoutes(mux)

	// Apply middleware
	var handler http.Handler = mux
	handler = api.SecurityMiddleware(handler)
	handler = api.LoggingMiddleware(handler)

	server := &http.Server{
		Addr:         fmt.Sprintf("%s:%s", host, port),
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		fmt.Printf("🚀 VelocityTasks server starting on http://%s:%s\n", host, port)
		fmt.Printf("📁 Serving static files from: %s\n", staticDir)
		fmt.Printf("💾 Max tasks: %d\n", maxTasks)
		if persistence.Enabled {
			fmt.Printf("💾 Persistence enabled: %s\n", persistence.FilePath)
		}
		fmt.Println("✨ Ready to manage your tasks!")

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	fmt.Println("\n🛑 Shutting down server...")

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Error during server shutdown: %v", err)
	}

	fmt.Println("✅ Server shutdown complete")
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt gets an environment variable as integer with a default value
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal := parseIntSafe(value); intVal > 0 {
			return intVal
		}
	}
	return defaultValue
}

// getEnvBool gets an environment variable as boolean with a default value
func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		return value == "true" || value == "1"
	}
	return defaultValue
}

// parseIntSafe safely parses an integer, returning 0 on error
func parseIntSafe(s string) int {
	var result int
	fmt.Sscanf(s, "%d", &result)
	return result
}
