# 💬 Chat Application (Flutter + FastAPI + Firebase)

A secure, full-stack chat application built with **Flutter** for the frontend, **FastAPI** as the backend API layer, and **Firebase** for authentication and data storage.  
The system follows a **layered architecture**, ensuring the frontend never directly interacts with the database while supporting real-time communication via **WebSockets**.

---

## 🚀 Features

- User authentication (signup, login, logout, password management)
- User profile creation and management
- One-to-one chat creation
- Send and retrieve chat messages
- Real-time messaging using WebSockets
- Chat history retrieval
- Notification system for new messages
- Secure API-driven communication

---

## 🏗️ Architecture Overview



## 🏗️ Architecture Overview
Flutter Frontend
↓
FastAPI Backend (REST APIs)
↓
Firebase (Auth + Database)


- The frontend communicates with FastAPI using **REST APIs and WebSockets**
- FastAPI handles authentication, validation, and real-time message delivery
- Firebase is accessed exclusively through the backend using the Admin SDK

---

## 🧰 Tech Stack

### Frontend
- Flutter
- HTTP / Dio for REST API calls
- WebSocket for real-time messaging

### Backend
- FastAPI (Python)
- WebSockets
- Firebase Admin SDK
- RESTful API design

### Database & Authentication
- Firebase Firestore / Realtime Database
- Firebase Authentication

---

## 📌 API Overview

### Auth
- POST `/auth/signup`
- POST `/auth/login`
- POST `/auth/logout`
- GET `/auth/me`
- PUT `/auth/profile`
- POST `/auth/change-password`
- POST `/auth/reset-password`
- POST `/auth/confirm-password`

### Users
- POST `/users`
- GET `/users/{id}`

### Chats
- POST `/chats`
- GET `/chats`
- DELETE `/chats/{chatId}`

### Messages
- POST `/messages`
- GET `/messages/{chatId}`
- DELETE `/messages/{messageId}`

### Notifications
- GET `/notifications`

### WebSocket
- WS `/ws/chat/{chatId}` → real-time message exchange

---

## 🔐 Security Design

- No direct frontend access to Firebase
- Authentication enforced at backend level
- WebSocket connections validated using auth tokens
- All data access controlled through FastAPI

---

## 🎯 Project Purpose

This project was built as a **portfolio and live demo application** to demonstrate:
- Clean backend architecture
- Secure API and WebSocket integration
- Real-world authentication workflows
- Scalable chat system design

The focus is on clarity, correctness, and real-time communication without overengineering.

---

## 🛠️ Future Improvements

- Group chat support
- Message read receipts
- Media and file sharing
- Push notifications
- Online/offline presence indicators

---

## 📄 License

This project is open-source and intended for learning and demonstration purposes.

