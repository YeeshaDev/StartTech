// @title           MuchToDo API
// @version         1.0
// @description     This is a sample server for a ToDo application with user authentication.
// @termsOfService  http://swagger.io/terms/
// @contact.name   API Support
// @contact.url    http://www.swagger.io/support
// @contact.email  support@swagger.io
// @license.name  Apache 2.0
// @license.url   http://www.apache.org/licenses/LICENSE-2.0.html
// @host      localhost:8080
// @BasePath  /
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
// @description "Type 'Bearer' followed by a space and a JWT token."
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

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"

	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/auth"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/cache"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/config"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/database"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/handlers"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/middleware"
	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/routes"

	// Swagger imports
	_ "github.com/Innocent9712/much-to-do/Server/MuchToDo/docs" // This is required for swag to find your docs
)

const usernameCacheSentinelKey = "username_cache_initialized"
const usernameCacheTTL = 24 * time.Hour

func main() {
	// 1. Load Configuration
	cfg, err := config.LoadConfig(".")
	if err != nil {
		log.Fatalf("could not load config: %v", err)
	}

	// 2. Connect to Database
	dbClient, err := database.ConnectMongo(cfg.MongoURI, cfg.DBName)
	if err != nil {
		log.Fatalf("could not connect to MongoDB: %v", err)
	}
	defer func() {
		if err = dbClient.Disconnect(context.Background()); err != nil {
			log.Printf("Error disconnecting from MongoDB: %v", err)
		}
	}()
	log.Println("Successfully connected to MongoDB.")

	// 3. Initialize Services (Cache, Auth)
	cacheService := cache.NewCacheService(cfg)
	tokenService := auth.NewTokenService(cfg.JWTSecretKey, cfg.JWTExpirationHours)

	// Preload usernames into cache if enabled
	preloadUsernamesIntoCache(dbClient, cacheService, cfg)

	// 4. Set up API router
	router := setupRouter(dbClient, cfg, tokenService, cacheService)

	// 5. Start Server with graceful shutdown
	startServer(router, cfg.ServerPort)
}

// preloadUsernamesIntoCache queries for all usernames and loads them into the cache,
// but only if caching is enabled and a sentinel key indicates the cache is empty.
func preloadUsernamesIntoCache(db *mongo.Client, cacheSvc cache.Cache, cfg config.Config) {
	if !cfg.EnableCache {
		log.Println("Caching is disabled. Skipping username preloading.")
		return
	}

	// Check if the cache has already been initialized in this cycle.
	var sentinelVal string
	err := cacheSvc.Get(context.Background(), usernameCacheSentinelKey, &sentinelVal)
	if err == nil {
		log.Println("Username cache already initialized. Skipping preload.")
		return
	}

	log.Println("Preloading usernames into cache...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	userCollection := db.Database(cfg.DBName).Collection("users")

	// Find all users, but only project the username field for efficiency
	opts := options.Find().SetProjection(bson.M{"username": 1})
	cursor, err := userCollection.Find(ctx, bson.D{}, opts)
	if err != nil {
		log.Printf("Error querying for usernames to preload: %v", err)
		return
	}
	defer cursor.Close(ctx)

	// Use a map to prepare for batch cache insertion
	usernamesToCache := make(map[string]interface{})
	for cursor.Next(ctx) {
		var result struct {
			Username string `bson:"username"`
		}
		if err := cursor.Decode(&result); err != nil {
			log.Printf("Error decoding username during preload: %v", err)
			continue
		}
		if result.Username != "" {
			cacheKey := fmt.Sprintf("username-taken:%s", result.Username)
			usernamesToCache[cacheKey] = true
		}
	}

	if err := cursor.Err(); err != nil {
		log.Printf("Cursor error during username preload: %v", err)
		return
	}

	if len(usernamesToCache) > 0 {
		err := cacheSvc.SetMany(ctx, usernamesToCache, usernameCacheTTL)
		if err != nil {
			log.Printf("Error preloading usernames to cache: %v", err)
		} else {
			// Set the sentinel key to prevent re-loading until it expires.
			cacheSvc.Set(ctx, usernameCacheSentinelKey, "true", usernameCacheTTL)
			log.Printf("Successfully preloaded %d usernames into the cache.", len(usernamesToCache))
		}
	} else {
		log.Println("No usernames found to preload.")
	}
}


// setupRouter initializes the Gin router and sets up the routes.
func setupRouter(db *mongo.Client, cfg config.Config, tokenSvc *auth.TokenService, cacheSvc cache.Cache) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.Default()

	// Initialize collections
	todoCollection := db.Database(cfg.DBName).Collection("todos")
	userCollection := db.Database(cfg.DBName).Collection("users")

	// Initialize handlers
	todoHandler := handlers.NewTodoHandler(todoCollection)
	userHandler := handlers.NewUserHandler(userCollection, tokenSvc, cacheSvc, db, cfg)
	healthHandler := handlers.NewHealthHandler(db, cacheSvc, cfg.EnableCache)

	// Auth Middleware
	authMiddleware := middleware.AuthMiddleware(tokenSvc)

	// Register all routes
	routes.RegisterRoutes(router, userHandler, todoHandler, healthHandler, authMiddleware)

	// A simple ping route for health checks
	router.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "pong"})
	})

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "Welcome to MuchToDo API"})
	})

	// Handle 404
	router.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Route not found"})
	})

	return router
}

// startServer starts the HTTP server and handles graceful shutdown.
func startServer(router *gin.Engine, port string) {
	srv := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	go func() {
		// Service connections
		log.Printf("Server listening on port %s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server with a timeout.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exiting.")
}
