import { io as createClient } from 'socket.io-client';

const SOCKET_URL = process.env.SOCKET_URL || 'http://localhost:4000';
const socket = createClient(SOCKET_URL, {
  transports: ['websocket'],
});

socket.on('connect', () => {
  console.log(`[test-socket-client] connected to ${SOCKET_URL} as ${socket.id}`);
});

socket.on('live_conditions_update', (payload) => {
  console.log('[test-socket-client] live_conditions_update', payload);
});

socket.on('disconnect', (reason) => {
  console.log(`[test-socket-client] disconnected: ${reason}`);
});

socket.on('connect_error', (error) => {
  console.error('[test-socket-client] connection failed:', error.message);
});
