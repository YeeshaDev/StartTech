package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type User struct {
	ID    primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	Name  string             `json:"name" bson:"name"`
	Email string             `json:"email" bson:"email"`
}

type Response struct {
	Message string `json:"message"`
}

var client *mongo.Client
var collection *mongo.Collection

func connectDB() {
	mongoURI := os.Getenv("MONGODB_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var err error
	client, err = mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("Failed to connect to MongoDB: %v", err)
	}

	if err = client.Ping(ctx, nil); err != nil {
		log.Fatalf("Failed to ping MongoDB: %v", err)
	}

	dbName := os.Getenv("DB_NAME")
	if dbName == "" {
		dbName = "muchtodo"
	}

	collection = client.Database(dbName).Collection("users")
	log.Println("Connected to MongoDB successfully")
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	if err := client.Ping(ctx, nil); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unhealthy", "error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "healthy"})
}

func getUsers(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var users []User
	if err = cursor.All(ctx, &users); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}

	if users == nil {
		users = []User{}
	}
	writeJSON(w, http.StatusOK, users)
}

func createUser(w http.ResponseWriter, r *http.Request) {
	var user User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Message: err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := collection.InsertOne(ctx, user)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}

	user.ID = result.InsertedID.(primitive.ObjectID)
	writeJSON(w, http.StatusCreated, user)
}

func getUser(w http.ResponseWriter, r *http.Request) {
	id, err := primitive.ObjectIDFromHex(mux.Vars(r)["id"])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Message: "invalid user ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var user User
	err = collection.FindOne(ctx, bson.M{"_id": id}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		writeJSON(w, http.StatusNotFound, Response{Message: "user not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func updateUser(w http.ResponseWriter, r *http.Request) {
	id, err := primitive.ObjectIDFromHex(mux.Vars(r)["id"])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Message: "invalid user ID"})
		return
	}

	var user User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Message: err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := collection.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"name": user.Name, "email": user.Email}})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}
	if result.MatchedCount == 0 {
		writeJSON(w, http.StatusNotFound, Response{Message: "user not found"})
		return
	}

	user.ID = id
	writeJSON(w, http.StatusOK, user)
}

func deleteUser(w http.ResponseWriter, r *http.Request) {
	id, err := primitive.ObjectIDFromHex(mux.Vars(r)["id"])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Message: "invalid user ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := collection.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Message: err.Error()})
		return
	}
	if result.DeletedCount == 0 {
		writeJSON(w, http.StatusNotFound, Response{Message: "user not found"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Message: "user deleted successfully"})
}

func main() {
	connectDB()

	r := mux.NewRouter()
	r.HandleFunc("/health", healthHandler).Methods(http.MethodGet)
	r.HandleFunc("/users", getUsers).Methods(http.MethodGet)
	r.HandleFunc("/users", createUser).Methods(http.MethodPost)
	r.HandleFunc("/users/{id}", getUser).Methods(http.MethodGet)
	r.HandleFunc("/users/{id}", updateUser).Methods(http.MethodPut)
	r.HandleFunc("/users/{id}", deleteUser).Methods(http.MethodDelete)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("MuchTodo server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
