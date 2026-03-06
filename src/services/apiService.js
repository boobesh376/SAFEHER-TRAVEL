import axios from 'axios';

const API_BASE_URL = 'http://localhost:5000/api';

/**
 * Create an axios instance with auth headers.
 * Call setAuthToken(token) after login to attach JWT.
 */
const apiClient = axios.create({
  baseURL: API_BASE_URL,
});

let authToken = null;

export const setAuthToken = (token) => {
  authToken = token;
  if (token) {
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  } else {
    delete apiClient.defaults.headers.common['Authorization'];
  }
};

export const getAuthToken = () => authToken;

export const activateSOS = async (location) => {
  try {
    const response = await apiClient.post('/sos/trigger', {
      latitude: location.lat,
      longitude: location.lng,
    });
    return response.data;
  } catch (error) {
    console.error('Error activating SOS:', error);
    throw error;
  }
};

export const getSOSStatus = async (sosId) => {
  try {
    const response = await apiClient.get(`/sos/history`);
    return response.data;
  } catch (error) {
    console.error('Error getting SOS status:', error);
    throw error;
  }
};

export const sendChatMessage = async (message, conversationId = null) => {
  try {
    const response = await apiClient.post('/chat/message', {
      message: message,
      conversation_id: conversationId,
    });
    return response.data;
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
};

export const getPoliceStations = async (lat, lng) => {
  try {
    const response = await apiClient.get(
      `/resources/police-stations?lat=${lat}&lng=${lng}`
    );
    return response.data;
  } catch (error) {
    console.error('Error getting police stations:', error);
    throw error;
  }
};

export const getHospitals = async (lat, lng) => {
  try {
    const response = await apiClient.get(
      `/resources/hospitals?lat=${lat}&lng=${lng}`
    );
    return response.data;
  } catch (error) {
    console.error('Error getting hospitals:', error);
    throw error;
  }
};