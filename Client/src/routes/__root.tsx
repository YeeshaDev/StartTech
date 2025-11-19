import { createRootRoute, Link, Outlet, useNavigate } from '@tanstack/react-router'
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools'
import { useAuth } from '@/hooks/useAuth'
import { LogOut, CheckSquare } from 'lucide-react'

const RootLayout = () => {
    const { logout, isAuthenticated } = useAuth()
    const navigate = useNavigate()

    const handleLogout = () => {
        logout()
        navigate({ to: '/login' })
    }

    return (
        <div className="min-h-screen bg-gray-50 font-sans text-gray-900">
            <nav className="bg-white shadow-sm border-b border-gray-200">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between h-16">
                        <div className="flex">
                            <Link to="/" className="flex-shrink-0 flex items-center gap-2">
                                <CheckSquare className="h-8 w-8 text-indigo-600" />
                                <span className="text-xl font-bold text-gray-900">MuchToDo</span>
                            </Link>
                        </div>
                        <div className="flex items-center gap-4">
                            {isAuthenticated ? (
                                <>
                                    <Link
                                        to="/todos"
                                        className="text-gray-700 hover:text-indigo-600 px-3 py-2 rounded-md text-sm font-medium transition-colors [&.active]:text-indigo-600 [&.active]:bg-indigo-50"
                                    >
                                        My Tasks
                                    </Link>
                                    <div className="h-6 w-px bg-gray-200 mx-2" />
                                    <button
                                        onClick={handleLogout}
                                        className="flex items-center gap-2 text-gray-500 hover:text-red-600 px-3 py-2 rounded-md text-sm font-medium transition-colors"
                                    >
                                        <LogOut className="w-4 h-4" />
                                        Sign out
                                    </button>
                                </>
                            ) : (
                                <>
                                    <Link
                                        to="/login"
                                        className="text-gray-700 hover:text-indigo-600 px-3 py-2 rounded-md text-sm font-medium transition-colors [&.active]:text-indigo-600"
                                    >
                                        Sign in
                                    </Link>
                                    <Link
                                        to="/register"
                                        className="bg-indigo-600 text-white hover:bg-indigo-700 px-4 py-2 rounded-md text-sm font-medium transition-colors shadow-sm"
                                    >
                                        Sign up
                                    </Link>
                                </>
                            )}
                        </div>
                    </div>
                </div>
            </nav>
            <main>
                <Outlet />
            </main>
            <TanStackRouterDevtools />
        </div>
    )
}

export const Route = createRootRoute({ component: RootLayout })
