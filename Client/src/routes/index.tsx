import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
    component: Index,
})

function Index() {
    return (
        <div className="p-2 bg-black">
            <h3 className='text-black'>Welcome Home!</h3>
        </div>
    )
}