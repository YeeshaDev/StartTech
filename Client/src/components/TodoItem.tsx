import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Trash2, CheckCircle, Circle } from 'lucide-react';
import { apiClient } from '@/lib/apiClient';
import type { Todo } from '@/types/todo.types';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

interface TodoItemProps {
    todo: Todo;
}

export function TodoItem({ todo }: TodoItemProps) {
    const queryClient = useQueryClient();

    const toggleMutation = useMutation({
        mutationFn: async () => {
            const response = await apiClient.put(`/todos/${todo.id}`, {
                completed: !todo.completed,
            });
            return response.data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['todos'] });
        },
        onError: () => {
            toast.error('Failed to update todo');
        },
    });

    const deleteMutation = useMutation({
        mutationFn: async () => {
            await apiClient.delete(`/todos/${todo.id}`);
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['todos'] });
            toast.success('Todo deleted');
        },
        onError: () => {
            toast.error('Failed to delete todo');
        },
    });

    return (
        <div className="flex items-center justify-between p-4 bg-white rounded-lg shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
            <div className="flex items-center gap-3 flex-1">
                <button
                    onClick={() => toggleMutation.mutate()}
                    disabled={toggleMutation.isPending}
                    className="text-gray-400 hover:text-indigo-600 transition-colors"
                >
                    {todo.completed ? (
                        <CheckCircle className="w-6 h-6 text-green-500" />
                    ) : (
                        <Circle className="w-6 h-6" />
                    )}
                </button>
                <div className="flex flex-col">
                    <span
                        className={cn(
                            "text-lg font-medium transition-all",
                            todo.completed ? "text-gray-400 line-through" : "text-gray-900"
                        )}
                    >
                        {todo.title}
                    </span>
                    {todo.description && (
                        <p className={cn("text-sm text-gray-500", todo.completed && "line-through opacity-70")}>
                            {todo.description}
                        </p>
                    )}
                </div>
            </div>
            <button
                onClick={() => deleteMutation.mutate()}
                disabled={deleteMutation.isPending}
                className="p-2 text-gray-400 hover:text-red-500 transition-colors rounded-full hover:bg-red-50"
                aria-label="Delete todo"
            >
                <Trash2 className="w-5 h-5" />
            </button>
        </div>
    );
}
