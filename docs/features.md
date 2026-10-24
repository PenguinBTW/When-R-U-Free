# Features & User Guide

When R U Free provides a complete suite of tools to enter, import, compare, and manage student timetables. Here is a detailed breakdown of all implemented capabilities.

---

## 1. Launch & Mode Selection

When you launch the app for the first time, you are presented with a mode choice:
- **Offline (Full Local Mode):** Complete privacy. Everything stays on your phone. No logins, accounts, or cloud connections. Friends are added by name, and timetables move peer-to-peer using QR codes or direct text snippets.
- **Sync (Cloud Vision):** Designed for automatic cross-device synchronization. Because the shared cloud database requires Firebase setup, tapping Sync presents a transparent status sheet detailing what is currently usable (Microsoft 365 calendar import, QR sharing) and allows a one-tap transition into offline mode.

---

## 2. Timetable Management

### Manual Entry
- **7-Day Tabs:** Dedicated views for Monday through Sunday.
- **Minimalist Form:** Enter only an event title and start/end times (location is optional). No clutter, no complicated recurrence rules.
- **Time Pickers:** Clean dialogs to pick hours and minutes in 5-minute increments.
- **Overlap Detection:** If an event overlaps another class on the same day, a warning banner appears immediately while editing.
- **Swipe-to-Delete:** Easily swipe any lesson card to remove it.
- **Batch Actions:** Quick menu items to clear a single day, clear all events, or load a realistic sample timetable.

### Editing Friends' Timetables
- Adding a timetable manually always happens under a picked friend's profile.
- You can inspect any friend from the Friends tab, view their weekly lessons, and edit or add their classes directly.

---

## 3. Microsoft 365 / Outlook Calendar Import

Students at colleges and universities often have their classes pushed directly to an institutional Microsoft 365 or Outlook calendar.

- **Direct Sign-In:** Sign in with your school, university, or personal Microsoft account via secure browser authentication (OAuth 2.0 PKCE).
- **Calendar Reading:** The app requests read-only delegated access (`Calendars.Read`) for the active week.
- **Intelligent Filtering:**
  - Automatically skips all-day events (e.g. holidays, birthdays).
  - Skips events marked as "Free" in Outlook.
  - Skips cancelled events.
  - Automatically splits multi-day or overnight events across day boundaries.
  - Automatically converts UTC timestamps into your local wall-clock timezone.
- **Selective Class Review:** Displays all discovered classes with checkboxes and time ranges. You pick which classes to import into your weekly timetable.
- **Deduplication:** Automatically skips classes that match existing entries to prevent duplicates.
- **Demo Mode:** Allows testing the entire import experience without connecting to Azure.

---

## 4. Live Availability & "Free Now" Dashboard

The **Home** screen acts as an intelligent daily dashboard:
- **Time-Aware Greeting:** Greets you with your name and today's date.
- **Live "Free Now" Status Card:**
  - Displays dynamic chips for every friend included in your group.
  - Green chips highlight who is free right this second.
  - If 5 or fewer friends are free, each chip displays **"till HH:MM"** indicating when that specific friend's next class begins.
  - Congratulates the group with a special highlight when everyone is free at the same time.
- **Next All-Free Slot Today:** Shows the earliest upcoming time window today where the entire group has a break.
- **Ranked Weekly Meetups:** Lists the top mutual breaks across the entire week, ranked by duration and participant headcount.
- **Today's Agenda:** Displays all your scheduled classes and any active one-off busy overrides for today.

---

## 5. Proportional Week Timeline

The **Week** screen presents a visual Mon–Fri timeline:
- **Adaptive Free Blocks:** Shared gaps scale proportionally in height according to their duration.
- **Skip Dividers:** Extended busy periods where you or your group are in lessons collapse into compact skip dividers.
- **Full Group Highlights:** Blocks where 100% of your friends are free are visually highlighted.
- **Only When You're Free:** The timeline exclusively renders times when *you* are free with at least one friend—lessons and times when you are busy never clutter the view.

---

## 6. Shared Break Drill-Down & Group Chat Export

Tapping any shared break card opens a bottom sheet:
- **Headcount Ratio:** Clear tally (e.g., `4/5 free`).
- **Participant Breakdown:** Lists every member in your group, clearly indicating who is "Free" vs. "In a lesson".
- **One-Tap Chat Copy:** Tapping **"Copy plan for group chat"** copies a formatted text message to your clipboard:
  ```text
  Free: Thu 13:00–14:30 (1h 30m) — Alex, Jess, Tim
  ```
- **"I'm Actually Busy Then":** One tap carves out your personal availability for that specific date without modifying your recurring timetable.

---

## 7. "I'm Actually Busy Then" (One-Off Overrides)

Weekly timetables don't account for doctor's visits, errands, or spontaneous study sessions:
- Any shared gap has an **"I'm actually busy then"** button.
- Creates a `BusyBlock` tied strictly to that calendar date (`YYYY-MM-DD`).
- Immediately updates gap calculations, the week timeline, the dashboard, and notification schedules.
- Manage or remove overrides at any time from **Timetable → Busy Overrides**.

---

## 8. Offline P2P Timetable Sharing (QR & Text)

Sharing timetables requires no cloud account or central server:
- **QR Code Sharing:**
  - Tap the QR icon on Home or Timetable to generate a high-density QR code encoding your entire weekly timetable (`WRF1-...`).
  - Friends point their camera using **Friends → Scan QR** to import your classes instantly.
- **Text Code Sharing:**
  - If a friend is remote or scanning fails, one tap switches to a portable share-text string.
  - Send the text code through WhatsApp, Discord, iMessage, or SMS.
  - The receiver pastes it into **Friends → Paste code**.
- **Safe Matching:**
  - Importing matches an existing friend by name (updating their timetable) or creates a new friend entry.

---

## 9. Local Gap Notifications

Never miss an unexpected shared break:
- **On-Device Scheduling:** Utilizes native device notification systems (`flutter_local_notifications`).
- **Smart Recalculation:** Recomputes upcoming breaks across the next 7 days and schedules alerts in the background.
- **Configurable Advance Warning:** Set alerts to trigger at the exact start, or 5, 10, 15, or 30 minutes before a shared gap.
- **Context-Rich Alerts:** Notifications specify the time window and names of the friends who are free with you:
  ```text
  Free with Jess, Tim soon
  Today 13:00–14:30 • 1h 30m with Jess, Tim
  ```
- **Test Alert Button:** Settings includes a live test button to confirm OS notification permissions.

---

## 10. Data Backup, Restore & Reset

- **JSON Export:** Export your entire local database (profile, timetable, friends, busy overrides, day settings) to JSON and copy it to clipboard or share via native system sheets.
- **JSON Import:** Restore your complete setup on a new phone by pasting exported JSON.
- **Reset All Data:** One-click option to wipe local storage and cancel all scheduled notification triggers.
