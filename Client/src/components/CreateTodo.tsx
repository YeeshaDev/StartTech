import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { apiClient } from '@/lib/apiClient';
import { toast } from 'sonner';

const createTodoSchema = z.object({
    title: z.string().min(1, 'Title is required'),
    description: z.string().optional(),
});

type CreateTodoFormValues = z.infer<typeof createTodoSchema>;

export function CreateTodo() {
    const queryClient = useQueryClient();

    const {
        register,
        handleSubmit,
        reset,
        formState: { errors, isSubmitting },
    } = useForm<CreateTodoFormValues>({
        resolver: zodResolver(createTodoSchema),
    });

    const createMutation = useMutation({
        mutationFn: async (data: CreateTodoFormValues) => {
            const response = await apiClient.post('/todos', data);
            return response.data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['todos'] });
            reset();
            toast.success('Todo added');
        },
        onError: () => {
            toast.error('Failed to create todo');
        },
    });

    const onSubmit = (data: CreateTodoFormValues) => {
        createMutation.mutate(data);
    };

    return (
        <form onSubmit={handleSubmit(onSubmit)} className="mb-8 bg-white p-4 rounded-lg shadow-sm border border-gray-100">
            <div className="flex flex-col gap-4">
                <div className="flex gap-2">
                    <div className="flex-1">
                        <input
                            type="text"
                            placeholder="What needs to be done?"
                            className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                            {...register('title')}
                        />
                        {errors.title && (
                            <p className="text-red-500 text-xs mt-1">{errors.title.message}</p>
                        )}
                    </div>
                    <button
                        type="submit"
                        disabled={isSubmitting || createMutation.isPending}
                        className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 flex items-center gap-2 font-medium"
                    >
                        <Plus className="w-5 h-5" />
                        Add
                    </button>
                </div>
                <input
                    type="text"
                    placeholder="Description (optional)"
                    className="w-full px-4 py-2 text-sm rounded-md border border-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    {...register('description')}
                />
            </div>
        </form>
    );
}
