import { collection, addDoc, serverTimestamp, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '../config/firebase';

export interface LogActivityParams {
  page: 'announcements' | 'customer_support' | 'driver_support' | 'promotion' | 'offers' | 'verification';
  actionType: string;
  description: string;
  targetId?: string;
}

export async function logStaffActivity({ page, actionType, description, targetId }: LogActivityParams) {
  try {
    const user = auth.currentUser;
    if (!user) return;

    // Check if user is in 'staff' collection
    const staffSnap = await getDoc(doc(db, 'staff', user.uid));
    if (staffSnap.exists()) {
      const staffData = staffSnap.data();
      const staffName = staffData.fullName || `${staffData.firstName || ''} ${staffData.lastName || ''}`.trim() || staffData.email || 'Staff Member';
      
      await addDoc(collection(db, 'staff_activities'), {
        staffUid: user.uid,
        staffName,
        staffEmail: user.email || staffData.email || '',
        staffId: staffData.staffId || '',
        page,
        actionType,
        description,
        targetId: targetId || null,
        timestamp: serverTimestamp(),
      });
    }
  } catch (err) {
    console.error('Failed to log staff activity:', err);
  }
}
