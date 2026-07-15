Here is the complete step-by-step guide for the Frontend developer. It covers exactly what APIs to call and what Socket events to emit/listen for in every scenario:

---

### Scenario 1: Initializing the App (Global Setup)
When the user opens the application and logs in:
1. **Frontend:** Connects to the Socket server with the JWT token.
2. **Frontend:** Calls API `GET /chat/get-my-chats` to load the inbox (list of all chats, last messages, and unread counts).
3. **Frontend:** Listens to `chat:new_message` globally (to update the inbox unread count or show a push notification if the user receives a message while not inside that specific chat screen).

---

### Scenario 2: Starting a NEW Private Chat
When the user clicks "Message" on another user's profile:
1. **Frontend:** Calls API `POST /chat/create-chat/:userId` (passing the other user's ID).
   - If the chat already exists, the API returns the existing `chat` object (`created: false`).
   - If it's new, the API creates it and returns the `chat` object (`created: true`).
2. **Frontend:** Receives `chatId` from the API response.
3. **Frontend:** Emits Socket event `chat:join` with `{ chatId }` to join the real-time room.
4. **Frontend:** Opens the chat screen for that `chatId`.

---

### Scenario 3: Opening an EXISTING Chat
When the user clicks on an existing chat from their Inbox list:
1. **Frontend:** Calls API `GET /chat/get-chat/:chatId`.
   - The backend automatically marks all unread messages in this chat as "read".
   - The backend returns the full chat history (paginated).
2. **Frontend:** Emits Socket event `chat:join` with `{ chatId }`.
   - Now the user is ready to send and receive real-time messages.
3. **Frontend:** (Optional but recommended) Emits Socket event `chat:read_messages` with `{ chatId }` to tell the sender "I have opened the chat and read your previous messages".

---

### Scenario 4: Sending a Message
While inside an open chat:
1. **Frontend:** User types a message and hits send.
2. **Frontend:** Emits Socket event `chat:send_message` with `{ chatId, content, type: "TEXT" }`.
   - *Wait, doesn't the frontend call an API to send?* **No.** Sending is fully real-time through the socket. The backend saves it to the database automatically.
3. **Backend:** Emits `chat:new_message` to everyone else in the room.
4. **Frontend (Sender):** Uses the callback from `chat:send_message` to instantly add the successful message to their own screen.

---

### Scenario 5: Receiving a Message (While inside the chat)
1. **Frontend:** User is staring at the chat screen (already joined the room).
2. **Frontend:** Listens to Socket event `chat:new_message`.
3. **Frontend:** Checks if the incoming message's `chat_id` matches the currently open chat.
   - If it matches: Append the message to the scrollable screen.
   - Instantly emit `chat:read_messages` with `{ chatId }` so the sender gets a blue tick ✅✅ since you are actively looking at it.

---

### Scenario 6: Receiving a Message (While OUTSIDE the chat)
1. **Frontend:** User is on the Home screen or Inbox list.
2. **Frontend:** Listens to Socket event `chat:new_message`.
3. **Frontend:** Checks if the incoming message's `chat_id` matches the currently open chat.
   - It doesn't match (because no chat is open).
   - Increment the "Unread Count" badge for that chat in the Inbox list.
   - Do **not** emit `chat:read_messages` (because the user hasn't seen it yet).

---

### Scenario 7: Typing Indicators
When the user is typing:
1. **Frontend:** On keystroke, emit `chat:typing` with `{ chatId }`.
   - (Best practice: debounce this so it doesn't emit 100 times a second).
2. **Other Users:** Listen to `chat:user_typing` and display *"Ahmed is typing..."*
3. **Frontend:** When the user stops typing (or sends the message), emit `chat:stop_typing` with `{ chatId }`.
4. **Other Users:** Listen to `chat:user_stopped_typing` and hide the indicator.

---

### Scenario 8: Creating a Group Chat
1. **Frontend:** User selects multiple users and chooses a group name.
2. **Frontend:** Calls API `POST /chat/create-chat-group` with `{ name, userIds: [1, 2, 3] }`.
3. **Frontend:** Receives the new `chatId`.
4. **Frontend:** Emits `chat:join` with `{ chatId }` to start chatting.

---

### Scenario 9: Leaving a Chat (Closing the screen)
When the user presses the 'Back' button to leave the chat screen and go back to the Inbox:
1. **Frontend:** Emits Socket event `chat:leave` with `{ chatId }`.
   - This stops the socket from receiving events for that specific chat while they are browsing other parts of the app.