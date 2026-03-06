
"use client"

import { Navigation } from "@/components/Navigation"
import { Card, CardContent } from "@/components/ui/card"
import { ShieldAlert, MapPin, Siren, Hotel, MessageSquare, ArrowRight, Shield, Users } from "lucide-react"
import Link from "next/link"
import { useState, useEffect } from "react"

export default function Home() {
  const [location, setLocation] = useState<string | null>(null)

  useEffect(() => {
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition((position) => {
        setLocation(`${position.coords.latitude.toFixed(4)}, ${position.coords.longitude.toFixed(4)}`)
      }, () => {
        setLocation("Location access denied")
      })
    }
  }, [])

  return (
    <div className="min-h-screen md:pl-20 pb-20 md:pb-0">
      <Navigation />
      
      <main className="max-w-4xl mx-auto p-6 space-y-8">
        <header className="flex justify-between items-start">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="bg-primary/20 text-primary text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-tighter">Tamil Nadu Women's Edition</span>
            </div>
            <h1 className="text-3xl font-bold font-headline text-foreground">Safe Her Travel</h1>
            <p className="text-muted-foreground">Your trusted safety companion across Tamil Nadu.</p>
          </div>
          <div className="flex items-center gap-2 bg-white px-3 py-1.5 rounded-full border border-border shadow-sm">
            <MapPin className="w-4 h-4 text-primary" />
            <span className="text-xs font-medium">{location || "Locating..."}</span>
          </div>
        </header>

        {/* SOS Section */}
        <div className="flex flex-col items-center justify-center py-12 space-y-6">
          <Link href="/sos" className="relative group">
            <div className="absolute inset-0 bg-red-500 rounded-full blur-xl opacity-20 group-hover:opacity-30 transition-opacity sos-pulse"></div>
            <button className="relative w-48 h-48 bg-red-600 rounded-full border-8 border-red-100 shadow-2xl flex flex-col items-center justify-center text-white transition-transform active:scale-95 group-hover:scale-105">
              <Siren className="w-16 h-16 mb-2" />
              <span className="text-3xl font-black tracking-widest">SOS</span>
            </button>
          </Link>
          <p className="text-sm font-medium text-center max-w-xs text-muted-foreground">
            Trigger an emergency signal to TN Police and your contacts.
          </p>
        </div>

        {/* Quick Actions Grid */}
        <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card className="hover:shadow-md transition-shadow cursor-pointer overflow-hidden border-none bg-white">
            <Link href="/chat">
              <CardContent className="p-6 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600">
                  <MessageSquare className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold">Chat Assistance</h3>
                  <p className="text-sm text-muted-foreground">Immediate guidance during distress.</p>
                </div>
                <ArrowRight className="w-5 h-5 text-muted-foreground" />
              </CardContent>
            </Link>
          </Card>

          <Card className="hover:shadow-md transition-shadow cursor-pointer overflow-hidden border-none bg-white">
            <Link href="/nearby">
              <CardContent className="p-6 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-orange-100 flex items-center justify-center text-orange-600">
                  <ShieldAlert className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold">Local TN Resources</h3>
                  <p className="text-sm text-muted-foreground">Find nearby TN Police and Hospitals.</p>
                </div>
                <ArrowRight className="w-5 h-5 text-muted-foreground" />
              </CardContent>
            </Link>
          </Card>

          <Card className="hover:shadow-md transition-shadow cursor-pointer overflow-hidden border-none bg-white">
            <Link href="/hotels">
              <CardContent className="p-6 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center text-green-600">
                  <Hotel className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold">Verified Accommodations</h3>
                  <p className="text-sm text-muted-foreground">AI-vetted safe stays in Tamil Nadu.</p>
                </div>
                <ArrowRight className="w-5 h-5 text-muted-foreground" />
              </CardContent>
            </Link>
          </Card>

          <Card className="hover:shadow-md transition-shadow cursor-pointer overflow-hidden border-none bg-white">
            <Link href="/community">
              <CardContent className="p-6 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-purple-100 flex items-center justify-center text-purple-600">
                  <Users className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold">Community Safety</h3>
                  <p className="text-sm text-muted-foreground">Share travel experiences with others.</p>
                </div>
                <ArrowRight className="w-5 h-5 text-muted-foreground" />
              </CardContent>
            </Link>
          </Card>
        </section>

        <section className="bg-primary/10 rounded-2xl p-6 border border-primary/20 flex items-start gap-4">
          <div className="p-2 bg-primary rounded-lg text-white">
            <Shield className="w-5 h-5" />
          </div>
          <div>
            <h4 className="font-bold text-primary">Safety Tip for TN</h4>
            <p className="text-sm text-foreground/80 leading-relaxed">
              In case of emergency, the Tamil Nadu State Emergency number is 100 or 112. Use the 'Kavalan-SOS' feature if you're traveling solo in Chennai or other urban hubs.
            </p>
          </div>
        </section>
      </main>
    </div>
  )
}
