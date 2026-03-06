"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { MessageCircle, Send, ShieldCheck, ChevronLeft } from "lucide-react"
import Link from "next/link"
import { useState, useRef, useEffect } from "react"

export default function ChatPage() {
  const [messages, setMessages] = useState([
    { id: 1, role: 'assistant', text: "Hello, I'm your Safe Her Travel Assistant for Tamil Nadu. I'm here to help you stay safe. How can I assist you right now?" },
  ])
  const [input, setInput] = useState("")
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo(0, scrollRef.current.scrollHeight)
    }
  }, [messages])

  const handleSend = () => {
    if (!input.trim()) return
    const userMsg = { id: messages.length + 1, role: 'user', text: input }
    setMessages(prev => [...prev, userMsg])
    setInput("")

    // Simple auto-reply logic for demo
    setTimeout(() => {
      let replyText = "I understand. I'm monitoring your safety. Would you like me to share your location with your contacts or find the nearest safe haven in Tamil Nadu?"
      if (input.toLowerCase().includes("hotel") || input.toLowerCase().includes("stay")) {
        replyText = "I can suggest some highly-rated safe hotels nearby in Tamil Nadu. Please check the 'Safe Hotels' section or would you like me to list them here?"
      } else if (input.toLowerCase().includes("help") || input.toLowerCase().includes("police") || input.toLowerCase().includes("kavalan")) {
        replyText = "I'm alerting your emergency contacts and notifying the nearest TN Police station now. Stay in a well-lit area. I've highlighted the nearest resources on your dashboard."
      }
      
      setMessages(prev => [...prev, { id: prev.length + 1, role: 'assistant', text: replyText }])
    }, 1000)
  }

  return (
    <div className="min-h-screen md:pl-20 flex flex-col bg-slate-50">
      <Navigation />
      
      <header className="p-4 bg-white border-b border-border flex items-center gap-4 sticky top-0 z-10">
        <Link href="/" className="md:hidden">
          <ChevronLeft className="w-6 h-6 text-muted-foreground" />
        </Link>
        <Avatar className="w-10 h-10 border border-primary/20">
          <AvatarFallback className="bg-primary text-white">
            <ShieldCheck className="w-6 h-6" />
          </AvatarFallback>
        </Avatar>
        <div>
          <h1 className="font-bold">Safe Her Travel Assistant</h1>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            <span className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">Active in Tamil Nadu</span>
          </div>
        </div>
      </header>

      <div className="flex-1 p-4 overflow-hidden relative">
        <ScrollArea className="h-[calc(100vh-14rem)] pr-4" ref={scrollRef}>
          <div className="space-y-4 py-4">
            {messages.map((m) => (
              <div key={m.id} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                <div className={`max-w-[85%] p-4 rounded-2xl text-sm leading-relaxed shadow-sm ${
                  m.role === 'user' 
                    ? 'bg-primary text-white rounded-tr-none' 
                    : 'bg-white text-foreground rounded-tl-none border border-border'
                }`}>
                  {m.text}
                </div>
              </div>
            ))}
          </div>
        </ScrollArea>
      </div>

      <div className="p-4 bg-white border-t border-border md:mb-0 mb-20">
        <div className="flex items-center gap-2 max-w-4xl mx-auto">
          <Input 
            placeholder="Type your message..." 
            className="flex-1 rounded-full bg-slate-100 border-none px-6 h-12"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
          />
          <Button 
            size="icon" 
            className="rounded-full w-12 h-12" 
            onClick={handleSend}
            disabled={!input.trim()}
          >
            <Send className="w-5 h-5" />
          </Button>
        </div>
      </div>
    </div>
  )
}
