"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { MapPin, Siren, Loader2, Phone, CheckCircle2, ChevronLeft } from "lucide-react"
import Link from "next/link"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { useToast } from "@/hooks/use-toast"
import { activateSOS } from "@/services/apiService"

export default function SOSPage() {
  const [isTriggered, setIsTriggered] = useState(false)
  const [countdown, setCountdown] = useState(5)
  const [isActivating, setIsActivating] = useState(false)
  const [sosId, setSosId] = useState<string | null>(null)
  const [policeInfo, setPoliceInfo] = useState<any>(null)
  const [userLocation, setUserLocation] = useState<{lat: number, lng: number} | null>(null)
  const router = useRouter()
  const { toast } = useToast()

  // Get user location on mount
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({
            lat: position.coords.latitude,
            lng: position.coords.longitude
          })
        },
        (error) => {
          console.error('Error getting location:', error)
          // Use default Chennai location if geolocation fails
          setUserLocation({ lat: 13.0827, lng: 80.2707 })
        }
      )
    } else {
      // Use default Chennai location
      setUserLocation({ lat: 13.0827, lng: 80.2707 })
    }
  }, [])

  useEffect(() => {
    let timer: NodeJS.Timeout
    if (isActivating && countdown > 0) {
      timer = setInterval(() => {
        setCountdown((c) => c - 1)
      }, 1000)
    } else if (isActivating && countdown === 0) {
      // Activate SOS with real backend
      activateSOSBackend()
    }
    return () => clearInterval(timer)
  }, [isActivating, countdown])

  const activateSOSBackend = async () => {
    if (!userLocation) {
      toast({
        title: "Location Error",
        description: "Unable to get your location. Please try again.",
        variant: "destructive"
      })
      setIsActivating(false)
      setCountdown(5)
      return
    }

    try {
      // Call real backend API
      const response = await activateSOS(
        'web_user', // TODO: Replace with actual user ID from auth context
        userLocation,
        [] // Emergency contacts are fetched from DB by backend
      )

      if (response.success) {
        setSosId(response.sos_id)
        setPoliceInfo(response.police_station)
        setIsTriggered(true)
        setIsActivating(false)
        
        toast({
          title: "SOS Signal Sent ✅",
          description: `Help is on the way! ETA: ${response.eta_minutes} minutes`,
        })
      }
    } catch (error) {
      console.error('SOS Activation Error:', error)
      toast({
        title: "Error",
        description: "Failed to activate SOS. Please call 100 directly.",
        variant: "destructive"
      })
      setIsActivating(false)
      setCountdown(5)
    }
  }

  const handleTrigger = () => {
    setIsActivating(true)
  }

  const handleCancel = () => {
    setIsActivating(false)
    setCountdown(5)
  }

  if (isTriggered) {
    return (
      <div className="min-h-screen md:pl-20 pb-20 md:pb-0 bg-white">
        <Navigation />
        <main className="max-w-4xl mx-auto p-6 space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">     
          <div className="flex flex-col items-center text-center space-y-6 pt-12">
            <div className="w-24 h-24 bg-green-100 rounded-full flex items-center justify-center text-green-600 animate-bounce">
              <CheckCircle2 className="w-12 h-12" />
            </div>
            <h1 className="text-4xl font-black text-foreground font-headline">Tamil Nadu Help is Active</h1>
            <p className="text-xl text-muted-foreground max-w-md">
              Your SOS signal has been sent to TN Police Dispatch and your emergency contacts.
            </p>
            {sosId && (
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm">
                <p className="font-mono text-blue-900">SOS ID: {sosId}</p>
              </div>
            )}
          </div>

          <Card className="border-none bg-blue-50 shadow-sm overflow-hidden">
            <CardHeader className="bg-primary text-white p-4">
              <CardTitle className="text-lg flex items-center gap-2">
                <Loader2 className="w-5 h-5 animate-spin" />
                Live TN Location Tracking
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <div className="h-64 bg-slate-200 relative flex items-center justify-center overflow-hidden">
                <img
                  src="https://picsum.photos/seed/chennai-map/800/600"
                  alt="Map Placeholder"
                  className="w-full h-full object-cover opacity-60 grayscale"
                />
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
                  <div className="w-8 h-8 bg-primary rounded-full border-4 border-white shadow-lg animate-ping"></div>
                  <MapPin className="w-8 h-8 text-primary absolute -top-1" />
                </div>
                <div className="absolute bottom-4 left-4 bg-white/90 backdrop-blur-sm p-3 rounded-lg shadow-sm border border-border">
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Current Status</p>  
                  {policeInfo ? (
                    <div>
                      <p className="text-sm font-medium">{policeInfo.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {policeInfo.distance_km}km away • ETA {policeInfo.eta_minutes}m
                      </p>
                    </div>
                  ) : (
                    <p className="text-sm font-medium">TN Police En-route (ETA 6m)</p>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="grid grid-cols-2 gap-4">
            <Button variant="outline" className="h-16 flex items-center gap-2 text-lg" asChild>
              <a href="tel:100">
                <Phone className="w-5 h-5" /> Call Police (100)
              </a>
            </Button>
            <Button variant="outline" className="h-16 flex items-center gap-2 text-lg" asChild>
              <a href="tel:108">
                <Phone className="w-5 h-5" /> Call Ambulance (108)
              </a>
            </Button>
          </div>

          <Button
            variant="ghost"
            className="w-full h-12 text-muted-foreground"
            onClick={() => setIsTriggered(false)}
          >
            I am safe now - Stop Sharing
          </Button>
        </main>
      </div>
    )
  }

  return (
    <div className="min-h-screen md:pl-20 pb-20 md:pb-0 bg-slate-50">
      <Navigation />
      <main className="max-w-4xl mx-auto p-6 space-y-8">
        <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground transition-colors">
          <ChevronLeft className="w-5 h-5 mr-1" /> Back to Dashboard
        </Link>

        <div className="text-center space-y-4 pt-8">
          <h1 className="text-3xl font-black font-headline text-foreground">Safe Her Travel SOS</h1>
          <p className="text-muted-foreground max-w-sm mx-auto">
            Activating SOS will immediately notify local TN authorities and your family with your real-time location. 
          </p>
        </div>

        <div className="flex flex-col items-center justify-center py-12">
          {!isActivating ? (
            <button
              onClick={handleTrigger}
              className="w-64 h-64 bg-red-600 rounded-full border-8 border-red-200 shadow-2xl flex flex-col items-center justify-center text-white transition-all hover:scale-105 active:scale-95 group"
            >
              <Siren className="w-24 h-24 mb-2 animate-pulse" />
              <span className="text-4xl font-black">HOLD SOS</span>
            </button>
          ) : (
            <div className="flex flex-col items-center space-y-8">
              <div className="relative w-64 h-64 flex items-center justify-center">
                <svg className="absolute inset-0 w-full h-full transform -rotate-90">
                  <circle
                    className="text-slate-200"
                    strokeWidth="8"
                    stroke="currentColor"
                    fill="transparent"
                    r="120"
                    cx="128"
                    cy="128"
                  />
                  <circle
                    className="text-red-600 transition-all duration-1000 ease-linear"
                    strokeWidth="8"
                    strokeDasharray={753.9}
                    strokeDashoffset={753.9 * (countdown / 5)}
                    strokeLinecap="round"
                    stroke="currentColor"
                    fill="transparent"
                    r="120"
                    cx="128"
                    cy="128"
                  />
                </svg>
                <div className="text-6xl font-black text-red-600">{countdown}</div>
              </div>
              <Button
                variant="destructive"
                size="lg"
                className="px-12 h-14 rounded-full text-xl"
                onClick={handleCancel}
              >
                CANCEL
              </Button>
            </div>
          )}
        </div>

        <section className="space-y-4">
          <h3 className="font-bold text-center">Your SOS will notify:</h3>
          <div className="flex justify-center gap-4">
            <div className="flex flex-col items-center gap-1">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm border border-border">100</div>
              <span className="text-xs text-muted-foreground">TN Police</span>
            </div>
            <div className="flex flex-col items-center gap-1">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm border border-border text-sm font-bold text-primary">112</div>
              <span className="text-xs text-muted-foreground">National ER</span>
            </div>
            <div className="flex flex-col items-center gap-1">
              <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm border border-border text-sm font-bold">EC</div>
              <span className="text-xs text-muted-foreground">Emergency Contacts</span>
            </div>
          </div>
        </section>
      </main>
    </div>
  )
}