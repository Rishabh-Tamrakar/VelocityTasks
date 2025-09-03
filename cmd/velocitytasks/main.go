package main

import (
	"context"
	"flag"
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
	// Command line flags
	var (
		port      = flag.String("port", "8080", "Server port")
		host      = flag.String("host", "localhost", "Server host")
		staticDir = flag.String("static", "web", "Static files directory")
		maxTasks  = flag.Int("max-tasks", 10000, "Maximum number of tasks")
		persist   = flag.Bool("persist", false, "Enable task persistence to file")
		persistFile = flag.String("persist-file", "tasks.json", "Persistence file path")
		version   = flag.Bool("version", false, "Show version information")
		help      = flag.Bool("help", false, "Show help information")
	)

	flag.Parse()

	if *help {
		showHelp()
		return
	}

	if *version {
		showVersion()
		return
	}

	// Initialize storage
	persistence := &storage.PersistenceConfig{
		Enabled:  *persist,
		FilePath: *persistFile,
	}

	taskStorage := storage.NewMemoryStorage(*maxTasks, persistence)

	// Initialize API server
	apiServer := api.NewServer(taskStorage, *staticDir)

	// Create HTTP server
	mux := http.NewServeMux()
	apiServer.SetupRoutes(mux)

	// Apply middleware
	var handler http.Handler = mux
	handler = api.SecurityMiddleware(handler)
	handler = api.LoggingMiddleware(handler)

	server := &http.Server{
		Addr:         fmt.Sprintf("%s:%s", *host, *port),
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		fmt.Printf("🚀 VelocityTasks CLI server starting on http://%s:%s\n", *host, *port)
		fmt.Printf("📁 Serving static files from: %s\n", *staticDir)
		fmt.Printf("💾 Max tasks: %d\n", *maxTasks)
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

func showHelp() {
	fmt.Println("VelocityTasks - Ultra-Lightweight Task Management Web Application")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  velocitytasks [options]")
	fmt.Println()
	fmt.Println("Options:")
	fmt.Println("  -port string        Server port (default: 8080)")
	fmt.Println("  -host string        Server host (default: localhost)")
	fmt.Println("  -static string      Static files directory (default: web)")
	fmt.Println("  -max-tasks int      Maximum number of tasks (default: 10000)")
	fmt.Println("  -persist            Enable task persistence to file")
	fmt.Println("  -persist-file string Persistence file path (default: tasks.json)")
	fmt.Println("  -version            Show version information")
	fmt.Println("  -help               Show this help message")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  velocitytasks                                    # Start with defaults")
	fmt.Println("  velocitytasks -port 3000 -host 0.0.0.0         # Custom host and port")
	fmt.Println("  velocitytasks -persist -persist-file data.json  # Enable persistence")
	fmt.Println("  velocitytasks -max-tasks 5000                   # Limit max tasks")
	fmt.Println()
	fmt.Println("Environment Variables:")
	fmt.Println("  PORT              Server port")
	fmt.Println("  HOST              Server host")
	fmt.Println("  STATIC_DIR        Static files directory")
	fmt.Println("  MAX_TASKS         Maximum number of tasks")
	fmt.Println("  ENABLE_PERSISTENCE Enable task persistence")
	fmt.Println("  PERSISTENCE_FILE  Persistence file path")
}

func showVersion() {
	fmt.Println("VelocityTasks v1.0.0")
	fmt.Println("Ultra-Lightweight Task Management Web Application")
	fmt.Println("Built with Go and ❤️")
	fmt.Println()
	fmt.Println("Author: Rishabh Tamrakar")
	fmt.Println("License: MIT")
	fmt.Println("Repository: https://github.com/rishabh-tamrakar/velocitytasks")
}
