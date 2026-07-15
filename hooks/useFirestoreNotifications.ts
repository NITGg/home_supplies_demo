"use client";

import { useEffect, useState, useCallback, useRef, useMemo } from "react";
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  where,
  Timestamp,
  doc,
  updateDoc,
  deleteDoc,
  startAfter,
  QueryDocumentSnapshot,
  getDocs,
  getCountFromServer,
  writeBatch,
} from "firebase/firestore";
import { useAuthContext } from "@/contexts/AuthContext";
import { db } from "@/firebase/firebase.config";

/**
 * Mock translation pattern consistent with previous components
 */
const tMock = (key: string, fallback?: string) => fallback || key;

export type NotificationData = Record<string, unknown> & {
  page?: string;
  type?: string;
};

export type NotificationRecord = {
  id: string;
  created_at: Timestamp;
  delivered_at: Timestamp | null;
  data: NotificationData;
  desc: string;
  desc_ar: string;
  is_read: boolean;
  title: string;
  title_ar: string;
  user_id: number;
};

interface Options {
  readonly limitCount?: number;
  readonly collectionName?: string;
  readonly lang?: "en" | "ar";
}

export function useFirestoreNotifications({
  limitCount = 20,
  collectionName = "Notifications",
  lang = "en",
}: Options = {}) {
  const { user } = useAuthContext();

  // Reference-based "Source of Truth" to prevent snapshot/local-state collisions
  const notifMapRef = useRef<Map<string, NotificationRecord>>(new Map());
  const lastDocRef = useRef<QueryDocumentSnapshot | null>(null);
  const deletedIdsRef = useRef<Set<string>>(new Set());

  const [notifications, setNotifications] = useState<NotificationRecord[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /** Updates the visible state based on the current Map content */
  const flushMap = useCallback(() => {
    const sorted = Array.from(notifMapRef.current.values()).sort(
      (a, b) =>
        (b.created_at?.toMillis() ?? 0) - (a.created_at?.toMillis() ?? 0),
    );
    setNotifications(sorted);
    setUnreadCount(sorted.filter((n) => !n.is_read).length);
  }, []);

  const fetchTotalCount = useCallback(async () => {
    if (!user?.id) return;
    try {
      const q = query(
        collection(db, collectionName),
        where("user_id", "==", user.id),
      );
      const snap = await getCountFromServer(q);
      setTotalCount(snap.data().count);
    } catch (err) {
      console.error("[Firestore Notifications: Total Count]", err);
    }
  }, [user?.id, collectionName]);

  // Initial Realtime Listener
  useEffect(() => {
    if (!user?.id) {
      setLoading(false);
      return;
    }

    setLoading(true);
    deletedIdsRef.current.clear();
    notifMapRef.current.clear();

    const q = query(
      collection(db, collectionName),
      where("user_id", "==", user.id),
      orderBy("created_at", "desc"),
      limit(limitCount),
    );

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        snapshot.docChanges().forEach((change) => {
          const docId = change.doc.id;

          if (change.type === "removed" || deletedIdsRef.current.has(docId)) {
            notifMapRef.current.delete(docId);
          } else {
            notifMapRef.current.set(docId, {
              id: docId,
              ...(change.doc.data() as Omit<NotificationRecord, "id">),
            });
          }
        });

        if (snapshot.docs.length > 0) {
          lastDocRef.current = snapshot.docs[snapshot.docs.length - 1];
        }

        setHasMore(snapshot.docs.length === limitCount);
        flushMap();
        setLoading(false);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      },
    );

    fetchTotalCount();

    return () => {
      unsubscribe();
    };
  }, [user?.id, limitCount, collectionName, flushMap, fetchTotalCount]);

  const loadMore = useCallback(async () => {
    if (!user?.id || !lastDocRef.current || loadingMore || !hasMore) return;

    setLoadingMore(true);
    try {
      const q = query(
        collection(db, collectionName),
        where("user_id", "==", user.id),
        orderBy("created_at", "desc"),
        startAfter(lastDocRef.current),
        limit(limitCount),
      );

      const snapshot = await getDocs(q);

      snapshot.docs.forEach((docSnap) => {
        if (!deletedIdsRef.current.has(docSnap.id)) {
          notifMapRef.current.set(docSnap.id, {
            id: docSnap.id,
            ...(docSnap.data() as Omit<NotificationRecord, "id">),
          });
        }
      });

      if (snapshot.docs.length > 0) {
        lastDocRef.current = snapshot.docs[snapshot.docs.length - 1];
      }

      setHasMore(snapshot.docs.length === limitCount);
      flushMap();
    } catch (err) {
      console.error("[Firestore Notifications: Load More]", err);
    } finally {
      setLoadingMore(false);
    }
  }, [user?.id, loadingMore, hasMore, limitCount, collectionName, flushMap]);

  const markAsRead = useCallback(
    async (notifId: string) => {
      const existing = notifMapRef.current.get(notifId);
      if (!existing || existing.is_read) return;

      // Optimistic Update
      notifMapRef.current.set(notifId, { ...existing, is_read: true });
      flushMap();

      try {
        await updateDoc(doc(db, collectionName, notifId), { is_read: true });
      } catch (err) {
        // Rollback on failure
        notifMapRef.current.set(notifId, existing);
        flushMap();
        console.error("[Firestore Notifications: MarkAsRead]", err);
      }
    },
    [collectionName, flushMap],
  );

  const markAllAsRead = useCallback(async () => {
    const unread = Array.from(notifMapRef.current.values()).filter(
      (n) => !n.is_read,
    );
    if (unread.length === 0) return;

    // Optimistic Update
    unread.forEach((n) =>
      notifMapRef.current.set(n.id, { ...n, is_read: true }),
    );
    flushMap();

    try {
      const batch = writeBatch(db);
      unread.forEach((n) => {
        batch.update(doc(db, collectionName, n.id), { is_read: true });
      });
      await batch.commit();
    } catch (err) {
      console.error("[Firestore Notifications: MarkAllAsRead]", err);
      // Optional: Refetch or rollback logic here
    }
  }, [collectionName, flushMap]);

  const deleteNotification = useCallback(
    async (notifId: string) => {
      deletedIdsRef.current.add(notifId);
      notifMapRef.current.delete(notifId);
      flushMap();

      try {
        await deleteDoc(doc(db, collectionName, notifId));
        setTotalCount((c) => Math.max(0, c - 1));
      } catch (err) {
        console.error("[Firestore Notifications: Delete]", err);
      }
    },
    [collectionName, flushMap],
  );

  const deleteAllNotifications = useCallback(async () => {
    const allIds = Array.from(notifMapRef.current.keys());
    if (allIds.length === 0) return;

    allIds.forEach((id) => deletedIdsRef.current.add(id));
    notifMapRef.current.clear();
    flushMap();
    setTotalCount(0);
    setHasMore(false);

    try {
      const batch = writeBatch(db);
      allIds.forEach((id) => {
        batch.delete(doc(db, collectionName, id));
      });
      await batch.commit();
    } catch (err) {
      console.error("[Firestore Notifications: DeleteAll]", err);
    }
  }, [collectionName, flushMap]);

  const getLabel = useCallback(
    (notif: NotificationRecord) => ({
      title: lang === "ar" ? notif.title_ar || notif.title : notif.title,
      desc: lang === "ar" ? notif.desc_ar || notif.desc : notif.desc,
    }),
    [lang],
  );

  return {
    notifications,
    unreadCount,
    totalCount,
    loading,
    loadingMore,
    hasMore,
    error,
    lang,
    t: tMock,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    deleteAllNotifications,
    loadMore,
    getLabel,
  };
}
