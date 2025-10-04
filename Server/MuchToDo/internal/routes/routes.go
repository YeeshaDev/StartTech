package routes

import (
	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"

	"github.com/Innocent9712/much-to-do/Server/MuchToDo/internal/handlers"
)


// RegisterRoutes sets up all application routes.
func RegisterRoutes(
	router *gin.Engine,
	userHandler *handlers.UserHandler,
	todoHandler *handlers.TodoHandler,
	healthHandler *handlers.HealthHandler,
	authMiddleware gin.HandlerFunc,
) {
	// Public routes
	router.GET("/health", healthHandler.CheckHealth)

	// Swagger documentation route
	router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	authRoutes := router.Group("/auth")
	{
		authRoutes.POST("/register", userHandler.Register)
		authRoutes.POST("/login", userHandler.Login)
		authRoutes.POST("/logout", userHandler.Logout)
		authRoutes.GET("/username-check/:username", userHandler.CheckUsernameAvailability)
	}

	// Protected routes
	protected := router.Group("/")
	protected.Use(authMiddleware)
	{
		// Protected user routes
		protected.GET("/users/me", userHandler.GetCurrentUser)

		// Protected todo routes
		todoRoutes := protected.Group("/todos")
		{
			todoRoutes.POST("/", todoHandler.CreateTodo)
			todoRoutes.GET("/", todoHandler.GetAllTodos)
			todoRoutes.GET("/:id", todoHandler.GetTodoByID)
			todoRoutes.PUT("/:id", todoHandler.UpdateTodo)
			todoRoutes.DELETE("/:id", todoHandler.DeleteTodo)
		}
	}
}
