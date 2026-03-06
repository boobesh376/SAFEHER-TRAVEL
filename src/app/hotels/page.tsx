
"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { Hotel, MapPin, ShieldCheck, Loader2, ChevronLeft, Search } from "lucide-react"
import Link from "next/link"
import { useState } from "react"
import { suggestSafeHotels, type HotelSuggestionsOutput } from "@/ai/flows/hotel-suggestions-flow"
import { useToast } from "@/hooks/use-toast"

export default function HotelsPage() {
  const [loading, setLoading] = useState(false)
  const [safetyConcerns, setSafetyConcerns] = useState("")
  const [results, setResults] = useState<HotelSuggestionsOutput | null>(null)
  const { toast } = useToast()

  const handleSearch = async () => {
    setLoading(true)
    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        if (!navigator.geolocation) {
          reject(new Error("Geolocation is not supported by your browser"))
        } else {
          navigator.geolocation.getCurrentPosition(resolve, reject)
        }
      })
      
      const response = await suggestSafeHotels({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        safetyConcerns: safetyConcerns || "General safety and security needed."
      })
      
      setResults(response)
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "Location Error",
        description: error.message || "Please enable location services to find nearby hotels.",
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen md:pl-20 bg-slate-50 pb-20">
      <Navigation />
      <main className="max-w-4xl mx-auto p-6 space-y-8">
        <header className="space-y-2">
          <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground">
            <ChevronLeft className="w-5 h-5 mr-1" /> Dashboard
          </Link>
          <h1 className="text-3xl font-bold font-headline">Safe Hotel Finder</h1>
          <p className="text-muted-foreground">AI-powered suggestions based on safety reviews and real-time data.</p>
        </header>

        <Card className="border-none shadow-sm bg-white overflow-hidden">
          <CardContent className="p-6">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 space-y-2">
                <label className="text-sm font-bold ml-1">Safety Concerns (Optional)</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <Input 
                    placeholder="e.g., Solo traveler, need 24/7 security..." 
                    className="pl-10 h-12 bg-slate-50 border-none rounded-full"
                    value={safetyConcerns}
                    onChange={(e) => setSafetyConcerns(e.target.value)}
                  />
                </div>
              </div>
              <Button 
                className="h-12 px-8 rounded-full mt-auto bg-primary hover:bg-primary/90" 
                onClick={handleSearch}
                disabled={loading}
              >
                {loading ? <Loader2 className="w-5 h-5 animate-spin mr-2" /> : <Hotel className="w-5 h-5 mr-2" />}
                Find Safe Haven
              </Button>
            </div>
          </CardContent>
        </Card>

        {loading && (
          <div className="flex flex-col items-center justify-center py-20 space-y-4">
            <Loader2 className="w-12 h-12 animate-spin text-primary" />
            <p className="text-lg font-medium animate-pulse">Vetting hotels based on safety reports...</p>
          </div>
        )}

        {!loading && results && (
          <div className="grid grid-cols-1 gap-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
            {results.suggestions.map((hotel, i) => (
              <Card key={i} className="border-none shadow-sm hover:shadow-md transition-shadow overflow-hidden group">
                <div className="flex flex-col md:flex-row">
                  <div className="md:w-64 h-48 bg-slate-200 relative shrink-0">
                    <img 
                      src={`https://picsum.photos/seed/hotel-${i}/400/300`} 
                      alt={hotel.name}
                      className="w-full h-full object-cover"
                    />
                    <div className="absolute top-2 left-2">
                      <Badge className="bg-white/90 text-primary border-none flex items-center gap-1 shadow-sm">
                        <ShieldCheck className="w-3 h-3" /> Safety Score: {hotel.safetyScore}/10
                      </Badge>
                    </div>
                  </div>
                  <CardContent className="p-6 flex-1 flex flex-col justify-between">
                    <div>
                      <div className="flex justify-between items-start">
                        <h3 className="text-xl font-bold group-hover:text-primary transition-colors">{hotel.name}</h3>
                        <span className="text-sm font-bold text-green-600">{hotel.priceRange}</span>
                      </div>
                      <p className="text-sm text-muted-foreground flex items-center gap-1 mt-1 mb-3">
                        <MapPin className="w-3 h-3" /> {hotel.address}
                      </p>
                      <p className="text-sm text-foreground/80 leading-relaxed bg-slate-50 p-3 rounded-lg border-l-4 border-primary/20 italic">
                        "{hotel.googleReviewsSummary}"
                      </p>
                    </div>
                    <div className="mt-6 flex items-center gap-4">
                      <Button variant="default" className="flex-1 rounded-full bg-primary">Book Now</Button>
                      <Button variant="outline" className="flex-1 rounded-full">See Details</Button>
                    </div>
                  </CardContent>
                </div>
              </Card>
            ))}
          </div>
        )}

        {!loading && !results && (
          <div className="text-center py-20 space-y-4 bg-white rounded-3xl border border-dashed border-border">
            <div className="w-20 h-20 bg-primary/10 rounded-full flex items-center justify-center text-primary mx-auto">
              <ShieldCheck className="w-10 h-10" />
            </div>
            <h2 className="text-2xl font-bold">Safety First Accommodation</h2>
            <p className="text-muted-foreground max-w-sm mx-auto">
              Click the button above to discover hotels that prioritize your security and safety, specially vetted by our AI.
            </p>
          </div>
        )}
      </main>
    </div>
  )
}
