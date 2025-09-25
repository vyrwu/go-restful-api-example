package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	_ "github.com/vyrwu/go-restful-api-example/docs"
)

// @title Go Restful API Example
// @version 1.1
// @description This is a sample server for a Go Restful API example.
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url http://www.swagger.io/support
// @contact.email support@swagger.io

// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html

// @host localhost:8000
// @BasePath /
func main() {
	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/swagger/index.html")
	})

	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	r.GET("/health", HealthCheck)

	gopherRoutes := r.Group("/gophers")
	{
		gopherRoutes.POST("", CreateGopher)
		gopherRoutes.GET("", GetGophers)
		gopherRoutes.GET("/:id", GetGopherByID)
		gopherRoutes.PUT("/:id", UpdateGopher)
		gopherRoutes.DELETE("/:id", DeleteGopher)
	}

	if err := r.Run(":8000"); err != nil {
		log.Fatalf("failed to run server: %v", err)
	}
}

// Gopher represents the model for a gopher
type Gopher struct {
	ID   string `json:"id" example:"1"`
	Name string `json:"name" example:"Gopher"`
}

// CreateGopher godoc
// @Summary Create a new gopher
// @Description Create a new gopher
// @Tags Gophers
// @Accept  json
// @Produce  json
// @Param gopher body Gopher true "Gopher to create"
// @Success 201 {object} Gopher
// @Router /gophers [post]
func CreateGopher(c *gin.Context) {
	// TODO: Implement this
	c.JSON(http.StatusCreated, Gopher{})
}

// GetGophers godoc
// @Summary Get all gophers
// @Description Get all gophers
// @Tags Gophers
// @Produce  json
// @Success 200 {array} Gopher
// @Router /gophers [get]
func GetGophers(c *gin.Context) {
	// TODO: Implement this
	c.JSON(http.StatusOK, []Gopher{})
}

// GetGopherByID godoc
// @Summary Get a gopher by ID
// @Description Get a gopher by ID
// @Tags Gophers
// @Produce  json
// @Param id path string true "Gopher ID"
// @Success 200 {object} Gopher
// @Router /gophers/{id} [get]
func GetGopherByID(c *gin.Context) {
	// TODO: Implement this
	c.JSON(http.StatusOK, Gopher{})
}

// UpdateGopher godoc
// @Summary Update a gopher
// @Description Update a gopher
// @Tags Gophers
// @Accept  json
// @Produce  json
// @Param id path string true "Gopher ID"
// @Param gopher body Gopher true "Gopher to update"
// @Success 200 {object} Gopher
// @Router /gophers/{id} [put]
func UpdateGopher(c *gin.Context) {
	// TODO: Implement this
	c.JSON(http.StatusOK, Gopher{})
}

// DeleteGopher godoc
// @Summary Delete a gopher
// @Description Delete a gopher
// @Tags Gophers
// @Param id path string true "Gopher ID"
// @Success 204
// @Router /gophers/{id} [delete]
func DeleteGopher(c *gin.Context) {
	// TODO: Implement this
	c.Status(http.StatusNoContent)
}

// HealthCheck godoc
// @Summary Check health
// @Description Check Health.
// @Tags Probes
// @Accept json
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
