import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { createFileRoute, Link } from '@tanstack/react-router';
import { apiClient } from '@/lib/apiClient';
import { useAuth } from '@/hooks/useAuth';
import type { UpdateUserDTO } from '@/types/auth.types';
import { toast } from 'sonner';
import { User, KeyRound, Trash2, Save } from 'lucide-react';

const updateProfileSchema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
  username: z.string().min(3, 'Username must be at least 3 characters'),
});

type UpdateProfileFormValues = z.infer<typeof updateProfileSchema>;

export const Route = createFileRoute('/profile')({
  component: ProfilePage,
});

function ProfilePage() {
  const { user, setUser } = useAuth();
  const queryClient = useQueryClient();
  const [isEditing, setIsEditing] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm<UpdateProfileFormValues>({
    resolver: zodResolver(updateProfileSchema),
    defaultValues: {
      firstName: user?.firstName || '',
      lastName: user?.lastName || '',
      username: user?.username || '',
    },
  });

  const updateProfileMutation = useMutation({
    mutationFn: async (data: UpdateUserDTO) => {
      const response = await apiClient.put('/users/me', data);
      return response.data;
    },
    onSuccess: (data) => {
      setUser(data.user || data);
      queryClient.setQueryData(['currentUser'], data.user || data);
      toast.success('Profile updated successfully');
      setIsEditing(false);
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    onError: (err: any) => {
      const message = err.response?.data?.error || 'Failed to update profile';
      toast.error(message);
    },
  });

  const onSubmit = (data: UpdateProfileFormValues) => {
    updateProfileMutation.mutate(data);
  };

  const handleCancel = () => {
    reset();
    setIsEditing(false);
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
            <User className="h-8 w-8 text-indigo-600" />
            My Profile
          </h1>
          <p className="mt-2 text-gray-600">Manage your account settings and preferences</p>
        </div>

        {/* Profile Information Card */}
        <div className="bg-white rounded-lg border border-gray-200 p-6 shadow-sm mb-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold text-gray-900">Personal Information</h2>
            {!isEditing && (
              <button
                onClick={() => setIsEditing(true)}
                className="px-4 py-2 text-sm font-medium text-indigo-600 hover:text-indigo-700 border border-indigo-600 rounded-md hover:bg-indigo-50 transition-colors"
              >
                Edit Profile
              </button>
            )}
          </div>

          <form onSubmit={handleSubmit(onSubmit)}>
            <div className="space-y-4">
              {/* First Name */}
              <div>
                <label htmlFor="firstName" className="block text-sm font-medium text-gray-700 mb-1">
                  First Name
                </label>
                <input
                  id="firstName"
                  type="text"
                  disabled={!isEditing}
                  className={`w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 ${!isEditing ? 'bg-gray-50 text-gray-600' : ''
                    }`}
                  {...register('firstName')}
                />
                {errors.firstName && (
                  <p className="text-red-500 text-xs mt-1">{errors.firstName.message}</p>
                )}
              </div>

              {/* Last Name */}
              <div>
                <label htmlFor="lastName" className="block text-sm font-medium text-gray-700 mb-1">
                  Last Name
                </label>
                <input
                  id="lastName"
                  type="text"
                  disabled={!isEditing}
                  className={`w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 ${!isEditing ? 'bg-gray-50 text-gray-600' : ''
                    }`}
                  {...register('lastName')}
                />
                {errors.lastName && (
                  <p className="text-red-500 text-xs mt-1">{errors.lastName.message}</p>
                )}
              </div>

              {/* Username */}
              <div>
                <label htmlFor="username" className="block text-sm font-medium text-gray-700 mb-1">
                  Username
                </label>
                <input
                  id="username"
                  type="text"
                  disabled={!isEditing}
                  className={`w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 ${!isEditing ? 'bg-gray-50 text-gray-600' : ''
                    }`}
                  {...register('username')}
                />
                {errors.username && (
                  <p className="text-red-500 text-xs mt-1">{errors.username.message}</p>
                )}
              </div>
            </div>

            {/* Action Buttons */}
            {isEditing && (
              <div className="flex gap-3 mt-6">
                <button
                  type="submit"
                  disabled={!isDirty || updateProfileMutation.isPending}
                  className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 transition-colors"
                >
                  <Save className="h-4 w-4" />
                  {updateProfileMutation.isPending ? 'Saving...' : 'Save Changes'}
                </button>
                <button
                  type="button"
                  onClick={handleCancel}
                  className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
              </div>
            )}
          </form>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Change Password */}
          <Link
            to="/change-password"
            className="flex items-center gap-3 p-4 bg-white border border-gray-200 rounded-lg hover:border-indigo-300 hover:shadow-sm transition-all"
          >
            <div className="p-2 bg-indigo-100 rounded-lg">
              <KeyRound className="h-6 w-6 text-indigo-600" />
            </div>
            <div>
              <h3 className="font-medium text-gray-900">Change Password</h3>
              <p className="text-sm text-gray-500">Update your account password</p>
            </div>
          </Link>

          {/* Delete Account */}
          <button
            onClick={() => setShowDeleteModal(true)}
            className="flex items-center gap-3 p-4 bg-white border border-gray-200 rounded-lg hover:border-red-300 hover:shadow-sm transition-all text-left"
          >
            <div className="p-2 bg-red-100 rounded-lg">
              <Trash2 className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <h3 className="font-medium text-gray-900">Delete Account</h3>
              <p className="text-sm text-gray-500">Permanently delete your account</p>
            </div>
          </button>
        </div>

        {/* Delete Account Modal */}
        {showDeleteModal && (
          <DeleteAccountModal onClose={() => setShowDeleteModal(false)} />
        )}
      </div>
    </div>
  );
}

// Delete Account Modal Component
function DeleteAccountModal({ onClose }: { onClose: () => void }) {
  const { logout } = useAuth();
  const [password, setPassword] = useState('');
  const [confirmed, setConfirmed] = useState(false);

  const deleteAccountMutation = useMutation({
    mutationFn: async () => {
      await apiClient.delete('/users/me');
    },
    onSuccess: () => {
      toast.success('Account deleted successfully');
      logout();
      window.location.href = '/login';
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    onError: (err: any) => {
      const message = err.response?.data?.error || 'Failed to delete account';
      toast.error(message);
    },
  });

  const handleDelete = () => {
    if (!confirmed || !password) {
      toast.error('Please confirm and enter your password');
      return;
    }
    deleteAccountMutation.mutate();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-md w-full p-6">
        <h2 className="text-xl font-bold text-gray-900 mb-4">Delete Account</h2>

        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-md">
          <p className="text-sm text-red-800 font-medium mb-2">⚠️ Warning: This action cannot be undone!</p>
          <p className="text-sm text-red-700">
            Deleting your account will permanently remove all your data, including todos and profile information.
          </p>
        </div>

        <div className="space-y-4 mb-6">
          <div className="flex items-start">
            <input
              id="confirm-delete"
              type="checkbox"
              checked={confirmed}
              onChange={(e) => setConfirmed(e.target.checked)}
              className="mt-1 h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
            />
            <label htmlFor="confirm-delete" className="ml-2 text-sm text-gray-700">
              I understand this action cannot be undone and all my data will be permanently deleted
            </label>
          </div>

          <div>
            <label htmlFor="password-confirm" className="block text-sm font-medium text-gray-700 mb-1">
              Enter your password to confirm
            </label>
            <input
              id="password-confirm"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              placeholder="Your password"
            />
          </div>
        </div>

        <div className="flex gap-3">
          <button
            onClick={handleDelete}
            disabled={!confirmed || !password || deleteAccountMutation.isPending}
            className="flex-1 px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 disabled:opacity-50 transition-colors"
          >
            {deleteAccountMutation.isPending ? 'Deleting...' : 'Delete My Account'}
          </button>
          <button
            onClick={onClose}
            disabled={deleteAccountMutation.isPending}
            className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}
