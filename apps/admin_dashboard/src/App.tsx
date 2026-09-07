import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import { ProtectedRoute } from './auth/ProtectedRoute';
import { AdminLayout } from './layout/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { DriverRatingsPage } from './pages/DriverRatingsPage';
import { DriverReferralsPage } from './pages/DriverReferralsPage';
import { DriverTiersPage } from './pages/DriverTiersPage';
import { FinancePage } from './pages/FinancePage';
import { FraudPage } from './pages/FraudPage';
import { DriverSupportPage } from './pages/DriverSupportPage';
import { CustomerSupportPage } from './pages/CustomerSupportPage';
import { LoginPage } from './pages/LoginPage';
import { StaffLoginPage } from './pages/StaffLoginPage';
import { RidesPage } from './pages/RidesPage';
import { UsersPage } from './pages/UsersPage';
import { DriverProfilePage } from './pages/DriverProfilePage';
import { VerificationRequestsPage } from './pages/VerificationRequestsPage';
import { WithdrawalsPage } from './pages/WithdrawalsPage';
import { WebsiteHome } from './pages/website/WebsiteHome';
import { PrivacyPolicy } from './pages/website/PrivacyPolicy';
import { AccountDeletion } from './pages/website/AccountDeletion';
import { Support } from './pages/website/Support';
import { SpecialOffersPage } from './pages/SpecialOffersPage';
import { AnnouncementsPage } from './pages/AnnouncementsPage';
import { PromotionPage } from './pages/PromotionPage';
import { StaffManagementPage } from './pages/StaffManagementPage';
import { StaffDashboardPage } from './pages/StaffDashboardPage';
import { SettingsPage } from './pages/SettingsPage';
import { AppDeepLinkPage } from './pages/AppDeepLinkPage';
import { FleetVerificationPage } from './pages/FleetVerificationPage';
import { FleetSupportPage } from './pages/FleetSupportPage';

function App() {
  return (
    <AuthProvider>
      <Routes>
        {/* Public Website Routes */}
        <Route path="/" element={<WebsiteHome />} />
        <Route path="/privacy-policy" element={<PrivacyPolicy />} />
        <Route path="/account-deletion" element={<AccountDeletion />} />
        <Route path="/support" element={<Support />} />

        {/* Deep Link Fallback — served when app is not installed */}
        <Route path="/app" element={<AppDeepLinkPage />} />
        <Route path="/app/:type" element={<AppDeepLinkPage />} />
        <Route path="/app/:type/:code" element={<AppDeepLinkPage />} />

        {/* Staff Authentication & Portal Routes */}
        <Route path="/staff/login" element={<StaffLoginPage />} />
        <Route path="/staff" element={<ProtectedRoute />}>
          <Route element={<AdminLayout />}>
            <Route index element={<Navigate to="/staff/dashboard" replace />} />
            <Route path="dashboard" element={<StaffDashboardPage />} />
          </Route>
        </Route>

        {/* Admin Dashboard Routes */}
        <Route path="/admin/login" element={<LoginPage />} />
        <Route path="/admin" element={<ProtectedRoute />}>
          <Route element={<AdminLayout />}>
            <Route index element={<Navigate to="/admin/dashboard" replace />} />
            <Route path="dashboard" element={<DashboardPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="drivers/:driverId" element={<DriverProfilePage />} />
            <Route path="verification-requests" element={<VerificationRequestsPage />} />
            <Route path="verification-requests/:driverId" element={<DriverProfilePage />} />
            <Route path="fleet-verification" element={<FleetVerificationPage />} />
            <Route path="fleet-support" element={<FleetSupportPage />} />
            <Route path="driver-support" element={<DriverSupportPage />} />
            <Route path="customer-support" element={<CustomerSupportPage />} />
            <Route path="rides" element={<RidesPage />} />
            <Route path="finance" element={<FinancePage />} />
            <Route path="withdrawals" element={<WithdrawalsPage />} />
            <Route path="fraud" element={<FraudPage />} />
            <Route path="driver-tiers" element={<DriverTiersPage />} />
            <Route path="driver-referrals" element={<DriverReferralsPage />} />
            <Route path="driver-ratings" element={<DriverRatingsPage />} />
            <Route path="offers" element={<SpecialOffersPage />} />
            <Route path="promotion" element={<PromotionPage />} />
            <Route path="staff-management" element={<StaffManagementPage />} />
            <Route path="staff-dashboard" element={<StaffDashboardPage />} />
            <Route path="announcements" element={<AnnouncementsPage />} />
            <Route path="settings" element={<SettingsPage />} />
          </Route>
        </Route>
        
        {/* Fallbacks */}
        <Route path="/admin/*" element={<Navigate to="/admin/dashboard" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}

export default App;


