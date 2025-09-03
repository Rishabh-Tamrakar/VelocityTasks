package api

import (
	"net/http"
	"os"

	"github.com/rishabh-tamrakar/velocitytasks/internal/handlers"
	"github.com/rishabh-tamrakar/velocitytasks/internal/storage"
)

// Server represents the VelocityTasks API server
type Server struct {
	taskHandler *handlers.TaskHandler
	staticDir   string
}

// NewServer creates a new API server instance
func NewServer(storage storage.TaskStorage, staticDir string) *Server {
	return &Server{
		taskHandler: handlers.NewTaskHandler(storage),
		staticDir:   staticDir,
	}
}

// SetupRoutes configures all the API routes
func (s *Server) SetupRoutes(mux *http.ServeMux) {
	// API routes
	mux.HandleFunc("/api/tasks", s.corsWrapper(s.taskHandler.HandleTasks))
	mux.HandleFunc("/api/tasks/", s.corsWrapper(s.taskHandler.HandleTask))
	mux.HandleFunc("/api/tasks/search", s.corsWrapper(s.taskHandler.HandleSearchTasks))
	mux.HandleFunc("/api/stats", s.corsWrapper(s.taskHandler.HandleStats))
	
	// Health check
	mux.HandleFunc("/health", s.corsWrapper(s.taskHandler.HandleHealth))
	
	// Static file handler
	staticHandler := s.createStaticFileHandler()
	mux.Handle("/", staticHandler)
}

// corsWrapper adds CORS headers to any handler
func (s *Server) corsWrapper(handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Add CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// Log the request
		s.taskHandler.LogRequest(r)

		// Call the original handler
		handler(w, r)
	}
}

// createStaticFileHandler creates a handler for serving static files
func (s *Server) createStaticFileHandler() http.Handler {
	// Ensure static directory exists
	if _, err := os.Stat(s.staticDir); os.IsNotExist(err) {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "Static directory not found", http.StatusNotFound)
		})
	}

	fileServer := http.FileServer(http.Dir(s.staticDir))
	
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set cache headers for static files
		if r.URL.Path != "/" {
			w.Header().Set("Cache-Control", "max-age=3600") // 1 hour cache
		}

		// Check if it's an API route - if so, don't serve static files
		if len(r.URL.Path) >= 4 && r.URL.Path[:4] == "/api" {
			http.NotFound(w, r)
			return
		}

		// Check if it's a health check route
		if r.URL.Path == "/health" {
			http.NotFound(w, r)
			return
		}

		// For the root path, serve index.html
		if r.URL.Path == "/" {
			// Set no-cache for the main page to ensure updates are served
			w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
			w.Header().Set("Pragma", "no-cache")
			w.Header().Set("Expires", "0")
		}

		// Serve the file
		fileServer.ServeHTTP(w, r)
	})
}

// SecurityMiddleware adds security headers
func SecurityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		
		// Content Security Policy for the web app
		if r.URL.Path == "/" || (len(r.URL.Path) > 4 && r.URL.Path[:4] != "/api") {
			w.Header().Set("Content-Security-Policy", 
				"default-src 'self'; "+
				"script-src 'self' 'unsafe-inline'; "+
				"style-src 'self' 'unsafe-inline'; "+
				"img-src 'self' data:; "+
				"connect-src 'self'")
		}

		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware logs HTTP requests
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip logging for static assets to reduce noise
		if shouldLogRequest(r.URL.Path) {
			// You can implement more sophisticated logging here
			// For now, the individual handlers do their own logging
		}
		
		next.ServeHTTP(w, r)
	})
}

// shouldLogRequest determines if a request should be logged
func shouldLogRequest(path string) bool {
	// Skip logging for common static assets
	staticExts := []string{".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg", ".woff", ".woff2", ".ttf"}
	
	for _, ext := range staticExts {
		if len(path) >= len(ext) && path[len(path)-len(ext):] == ext {
			return false
		}
	}
	
	return true
}
