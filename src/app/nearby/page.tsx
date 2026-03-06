"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Hospital, Shield, MapPin, Phone, ExternalLink, ChevronLeft } from "lucide-react"
import Link from "next/link"
import { useState } from "react"

export default function NearbyResourcesPage() {
  const hospitals = [
    { name: "Apollo Hospitals, Greams Road", address: "Greams Lane, Off Greams Road, Chennai", distance: "1.2 km", phone: "044 2829 3333" },
    { name: "MIOT International", address: "Mount Poonamallee Road, Manapakkam, Chennai", distance: "5.4 km", phone: "044 4222 6000" },
    { name: "Madurai Medical College", address: "Panagal Rd, Alwarpuram, Madurai", distance: "2.1 km", phone: "0452 253 2531" },
  ]

  const police = [
    { name: "Greater Chennai Police Commissionerate", address: "Vepery High Road, Chennai", distance: "0.8 km", phone: "100" },
    { name: "K5 Peravallur Police Station", address: "Jawahar Nagar, Chennai", distance: "2.5 km", phone: "044 2345 2641" },
    { name: "B1 Madurai Town Police Station", address: "Simmakkal, Madurai", distance: "1.5 km", phone: "0452 234 6500" },
  ]

  return (
    <div className="min-h-screen md:pl-20 bg-slate-50 pb-20">
      <Navigation />
      <main className="max-w-4xl mx-auto p-6 space-y-6">
        <header className="space-y-2">
          <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground">
            <ChevronLeft className="w-5 h-5 mr-1" /> Dashboard
          </Link>
          <h1 className="text-3xl font-bold font-headline">Tamil Nadu Resources</h1>
          <p className="text-muted-foreground">Quick access to TN Police and major medical centers near you.</p>
        </header>

        <div className="h-48 bg-slate-200 rounded-2xl relative overflow-hidden shadow-inner">
          <img 
            src="https://picsum.photos/seed/tn-map/1200/400" 
            alt="Resource Map" 
            className="w-full h-full object-cover opacity-70 grayscale"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent"></div>
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center justify-center">
            <div className="w-6 h-6 bg-primary rounded-full border-2 border-white shadow-lg animate-pulse"></div>
          </div>
        </div>

        <Tabs defaultValue="police" className="w-full">
          <TabsList className="grid w-full grid-cols-2 bg-white h-12 p-1 border border-border rounded-full shadow-sm">
            <TabsTrigger value="police" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white">
              <Shield className="w-4 h-4 mr-2" /> TN Police
            </TabsTrigger>
            <TabsTrigger value="hospitals" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white">
              <Hospital className="w-4 h-4 mr-2" /> Hospitals
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="police" className="mt-6 space-y-4">
            {police.map((p, i) => (
              <Card key={i} className="border-none shadow-sm hover:shadow-md transition-shadow">
                <CardContent className="p-5 flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-orange-100 flex items-center justify-center text-orange-600 shrink-0">
                    <Shield className="w-6 h-6" />
                  </div>
                  <div className="flex-1">
                    <div className="flex justify-between items-start">
                      <h3 className="font-bold">{p.name}</h3>
                      <span className="text-xs font-bold text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full">{p.distance}</span>
                    </div>
                    <p className="text-sm text-muted-foreground flex items-center gap-1 mt-1">
                      <MapPin className="w-3 h-3" /> {p.address}
                    </p>
                    <div className="flex gap-2 mt-4">
                      <Button variant="outline" size="sm" className="flex-1 gap-2 rounded-full" asChild>
                        <a href={`tel:${p.phone}`}>
                          <Phone className="w-3 h-3" /> Call {p.phone}
                        </a>
                      </Button>
                      <Button size="sm" className="flex-1 gap-2 rounded-full">
                        <ExternalLink className="w-3 h-3" /> Navigate
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </TabsContent>

          <TabsContent value="hospitals" className="mt-6 space-y-4">
            {hospitals.map((h, i) => (
              <Card key={i} className="border-none shadow-sm hover:shadow-md transition-shadow">
                <CardContent className="p-5 flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center text-blue-600 shrink-0">
                    <Hospital className="w-6 h-6" />
                  </div>
                  <div className="flex-1">
                    <div className="flex justify-between items-start">
                      <h3 className="font-bold">{h.name}</h3>
                      <span className="text-xs font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">{h.distance}</span>
                    </div>
                    <p className="text-sm text-muted-foreground flex items-center gap-1 mt-1">
                      <MapPin className="w-3 h-3" /> {h.address}
                    </p>
                    <div className="flex gap-2 mt-4">
                      <Button variant="outline" size="sm" className="flex-1 gap-2 rounded-full" asChild>
                        <a href={`tel:${h.phone}`}>
                          <Phone className="w-3 h-3" /> Call
                        </a>
                      </Button>
                      <Button size="sm" className="flex-1 gap-2 rounded-full bg-blue-600 hover:bg-blue-700">
                        <ExternalLink className="w-3 h-3" /> Navigate
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </TabsContent>
        </Tabs>
      </main>
    </div>
  )
}
