package models

import (
	"go.mongodb.org/mongo-driver/bson/primitive"
	"golang.org/x/crypto/bcrypt"
)

// User represents a user in the system.
type User struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	FirstName string             `bson:"firstName" json:"firstName" binding:"required"`
	LastName  string             `bson:"lastName" json:"lastName" binding:"required"`
	Username  string             `bson:"username" json:"username" binding:"required"`
	Password  string             `bson:"password" json:"-"` // Never return password
	CreatedAt primitive.DateTime `bson:"createdAt" json:"createdAt"`
	UpdatedAt primitive.DateTime `bson:"updatedAt" json:"updatedAt"`
}

// HashPassword hashes the user's password using bcrypt.
func (u *User) HashPassword(password string) error {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	if err != nil {
		return err
	}
	u.Password = string(bytes)
	return nil
}

// CheckPasswordHash compares a plaintext password with the stored hash.
func (u *User) CheckPasswordHash(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}

// --- DTOs (Data Transfer Objects) for API input/output ---

type RegisterUserDTO struct {
	FirstName string `json:"firstName" binding:"required"`
	LastName  string `json:"lastName" binding:"required"`
	Username  string `json:"username" binding:"required,min=3"`
	Password  string `json:"password" binding:"required,min=6"`
}

type LoginUserDTO struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// PublicUser is a safe representation of a user to be sent in API responses.
type PublicUser struct {
	ID        primitive.ObjectID `json:"id"`
	FirstName string             `json:"firstName"`
	LastName  string             `json:"lastName"`
	Username  string             `json:"username"`
}
