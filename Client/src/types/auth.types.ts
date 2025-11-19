export interface User {
    id: string;
    firstName: string;
    lastName: string;
    username: string;
}

export interface AuthContextType {
    user: User | null;
    setUser: React.Dispatch<React.SetStateAction<User | null>>;
    isAuthenticated: boolean;
    logout: () => void;
    isLoading: boolean;
}
