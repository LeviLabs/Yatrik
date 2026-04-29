# Yatrik FastAPI Backend

# Yatrik Backend API

Backend server for **Yatrik Travel Recommendation System**.

This backend is built using **FastAPI** and provides machine-learning-based travel recommendations for the Yatrik Flutter app. It recommends tourist spots and generates a day-wise itinerary based on the user's selected city, state, trip duration, and travel preferences.

---

## Project Overview

**Yatrik Backend** helps the mobile app generate smart travel plans by using:

- User-selected city and state
- Number of trip days
- Travel preferences
- Tourist spot dataset
- Trained machine learning model
- Latitude and longitude for map integration

The backend returns recommended tourist places with details like place name, city, state, ideal visit hours, popularity score, match score, category, latitude, and longitude.

---

## Backend Folder Structure

    server/
    │
    ├── app.py
    ├── requirements.txt
    ├── rf_tourist_model.pkl
    ├── chhattisgarh_tourist_places.csv
    └── README.md

---

## Tech Stack

- Python
- FastAPI
- Uvicorn
- Pandas
- NumPy
- Scikit-learn
- Joblib
- Random Forest Machine Learning Model
- CSV Dataset

---

## Files Description

### app.py

Main FastAPI backend file. It loads the trained machine learning model and tourist dataset, then provides API endpoints for the Flutter app.

### rf_tourist_model.pkl

Trained Random Forest model used to recommend tourist places.

### chhattisgarh_tourist_places.csv

Tourist place dataset containing information such as:

- Place name
- City
- State
- Latitude
- Longitude
- Ideal hours
- Popularity score
- Tourist categories

### requirements.txt

Contains all Python packages required to run the backend.

---

## Install and Run Locally

### 1. Open the backend folder

    cd server

### 2. Create a virtual environment

    python -m venv venv

### 3. Activate the virtual environment

For Windows:

    venv\Scripts\activate

For Mac/Linux:

    source venv/bin/activate

### 4. Install dependencies

    pip install -r requirements.txt

### 5. Run the FastAPI server

    uvicorn app:app --reload

The backend will run at:

    http://127.0.0.1:8000

FastAPI documentation will be available at:

    http://127.0.0.1:8000/docs

---

## API Endpoints

## 1. Health Check

### Endpoint

    GET /

### Purpose

Used to check whether the backend server is running.

### Example Response

    {
      "message": "Yatrik backend is running"
    }

---

## 2. Travel Recommendation API

### Endpoint

    POST /recommend

### Purpose

This endpoint receives the user's travel details from the Flutter app and returns a personalized tourist spot itinerary.

---

## Request Body Example

    {
      "City": "Raipur",
      "State": "Chhattisgarh",
      "Days": 4,
      "Is_Museum": 1,
      "Is_Nature": 1,
      "Is_Beach": 0,
      "Is_History": 1,
      "Is_Temple": 0,
      "Is_Wildlife": 0,
      "Is_Shopping": 0,
      "Is_Foodie": 0
    }

---

## Request Fields

| Field | Type | Description |
|---|---|---|
| City | String | City selected by the user |
| State | String | State selected by the user |
| Days | Integer | Number of trip days |
| Is_Museum | Integer | Museum preference, 1 = selected, 0 = not selected |
| Is_Nature | Integer | Nature preference |
| Is_Beach | Integer | Beach preference |
| Is_History | Integer | Historical place preference |
| Is_Temple | Integer | Temple preference |
| Is_Wildlife | Integer | Wildlife preference |
| Is_Shopping | Integer | Shopping preference |
| Is_Foodie | Integer | Food place preference |

---

## Response Example

    {
      "success": true,
      "mode": "city",
      "place": "Raipur",
      "days": 4,
      "hours_per_day": 14,
      "preferences": [
        "Is_Museum",
        "Is_Nature",
        "Is_History"
      ],
      "spots_found": 20,
      "spots_added": 20,
      "itinerary": [
        {
          "day": 1,
          "place_name": "Nandanvan Zoo Raipur",
          "city": "Raipur",
          "state": "Chhattisgarh",
          "ideal_hours": 3.0,
          "popularity_score": 82.0,
          "match_score": 95.4,
          "categories": ["Wildlife"],
          "lat": 21.2100,
          "lng": 81.6300
        }
      ]
    }

---

## Response Fields

| Field | Description |
|---|---|
| success | Shows whether recommendation was successful |
| mode | Shows whether recommendation is based on city or state |
| place | Selected city or state |
| days | Number of trip days |
| hours_per_day | Daily trip planning limit |
| preferences | User-selected travel preferences |
| spots_found | Total matched tourist spots |
| spots_added | Tourist spots added into final itinerary |
| itinerary | Final day-wise tourist spot list |

---

## Map Integration

Each recommended tourist spot includes latitude and longitude:

    {
      "lat": 21.2100,
      "lng": 81.6300
    }

These coordinates are used by the Flutter app to show locations on the map.

The Flutter app can use this data to:

- Show tourist spot markers
- Draw routes between places
- Show day-wise trip paths
- Calculate road distance and travel time
- Display itinerary on Mapbox map

---

## Render Deployment Settings

Use the following Render settings:

    Root Directory: server
    Build Command: pip install -r requirements.txt
    Start Command: uvicorn app:app --host 0.0.0.0 --port $PORT

Recommended Python version:

    PYTHON_VERSION = 3.11.9

Add this in Render Environment Variables.

---

## requirements.txt

The backend requires these packages:

    fastapi
    uvicorn[standard]
    pandas
    numpy
    scikit-learn
    joblib

---

## Important Notes

- Keep app.py, requirements.txt, rf_tourist_model.pkl, and chhattisgarh_tourist_places.csv inside the same server folder.
- Do not delete the trained model file.
- Do not rename the CSV file unless you also update the filename inside app.py.
- The Flutter app should call the deployed Render backend URL.
- For local testing, use http://127.0.0.1:8000/recommend.
- For Android emulator testing, use http://10.0.2.2:8000/recommend.

---

## Project Purpose

The purpose of this backend is to support the **Yatrik Smart India Travel Planner** app.

It helps users by providing:

- Smart tourist spot recommendations
- Personalized travel planning
- Day-wise itinerary generation
- Preference-based filtering
- Location coordinates for map display
- Backend support for Flutter frontend

---

## GitHub Repository

This backend is part of the main project:

**Yatrik Travel Recommendation System**

---

## Author

Developed by **LeviLabs** for the Yatrik travel recommendation project.
