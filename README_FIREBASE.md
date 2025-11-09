This project includes ready-to-deploy Firestore rules and index configuration used by Module 12 (Admin Orders).

Files added:
- `firestore.rules` — security rules that:
  - allow authenticated users to create orders where userId == their uid
  - allow authenticated users to read only their own orders
  - allow admins (presence in `admins/{uid}`) to read and update any order
  - disallow client deletes

- `firestore.indexes.json` — includes a composite index for the `orders` collection:
  - userId: ASC, createdAt: DESC

How to deploy these using Firebase CLI (Windows PowerShell):

1. Install firebase tools if not installed:

   npm install -g firebase-tools

2. Login and set project:

   firebase login
   firebase use --add

3. Deploy rules and indexes:

   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes

Wait for the index build to finish in the Firebase Console (Firestore → Indexes). After the index is built and rules are published, restart the app and test Module 12.

NOTE: Deploying rules and indexes requires you to have firebase project access. These files added to the repo don't change your live Firebase project until you run the commands above.
