
"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { Home, Shield, MessageCircle, Star, Users } from "lucide-react"
import { cn } from "@/lib/utils"

export function Navigation() {
  const pathname = usePathname()

  const navItems = [
    { name: "Home", href: "/", icon: Home },
    { name: "Chat", href: "/chat", icon: MessageCircle },
    { name: "Resources", href: "/nearby", icon: Shield },
    { name: "Hotels", href: "/hotels", icon: Star },
    { name: "Community", href: "/community", icon: Users },
  ]

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-white border-t border-border px-4 py-2 flex justify-around items-center md:top-0 md:bottom-auto md:flex-col md:w-20 md:h-screen md:px-0 md:py-8 md:border-r md:border-t-0">
      <div className="hidden md:flex flex-col items-center mb-8">
        <div className="w-10 h-10 bg-primary rounded-full flex items-center justify-center text-white font-bold text-xs text-center leading-tight">SHT</div>
      </div>
      {navItems.map((item) => {
        const Icon = item.icon
        const isActive = pathname === item.href
        return (
          <Link
            key={item.name}
            href={item.href}
            className={cn(
              "flex flex-col items-center gap-1 p-2 rounded-lg transition-colors md:w-full md:px-0",
              isActive ? "text-primary" : "text-muted-foreground hover:text-primary hover:bg-primary/5"
            )}
          >
            <Icon className="w-6 h-6" />
            <span className="text-[10px] font-medium md:text-xs">{item.name}</span>
          </Link>
        )
      })}
    </nav>
  )
}
