
"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { MapPin, MessageSquare, ThumbsUp, ShieldCheck, AlertTriangle, User, ChevronLeft, Users } from "lucide-react"
import Link from "next/link"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"

type Report = {
  id: number
  user: string
  location: string
  experience: string
  type: 'safe' | 'warning' | 'info'
  time: string
}

export default function CommunityPage() {
  const { toast } = useToast()
  const [reports, setReports] = useState<Report[]>([
    {
      id: 1,
      user: "Priya S.",
      location: "Marina Beach, Chennai",
      experience: "The area is well-lit even after 9 PM. TN Police patrol is visible. Felt very safe walking with my sister.",
      type: 'safe',
      time: "2 hours ago"
    },
    {
      id: 2,
      user: "Anitha R.",
      location: "Madurai Junction",
      experience: "Be careful at the west exit late at night. The lighting is a bit dim and there are fewer people.",
      type: 'warning',
      time: "5 hours ago"
    },
    {
      id: 3,
      user: "Lakshmi K.",
      location: "Coimbatore Omni Bus Stand",
      experience: "Women's waiting room is clean and well-guarded. Great facility for solo travelers.",
      type: 'safe',
      time: "1 day ago"
    }
  ])

  const [newReport, setNewReport] = useState({
    location: "",
    experience: "",
    type: "safe" as const
  })
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!newReport.location || !newReport.experience) return

    const report: Report = {
      id: Date.now(),
      user: "You",
      location: newReport.location,
      experience: newReport.experience,
      type: newReport.type,
      time: "Just now"
    }

    setReports([report, ...reports])
    setNewReport({ location: "", experience: "", type: "safe" })
    setIsDialogOpen(false)
    toast({
      title: "Experience Shared!",
      description: "Thank you for helping the community stay safe in Tamil Nadu.",
    })
  }

  return (
    <div className="min-h-screen md:pl-20 bg-slate-50 pb-20">
      <Navigation />
      <main className="max-w-4xl mx-auto p-6 space-y-8">
        <header className="flex flex-col md:flex-row md:items-end justify-between gap-4">
          <div className="space-y-2">
            <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground">
              <ChevronLeft className="w-5 h-5 mr-1" /> Dashboard
            </Link>
            <h1 className="text-3xl font-bold font-headline">Travel Community</h1>
            <p className="text-muted-foreground">Real stories from women traveling across Tamil Nadu.</p>
          </div>
          
          <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <DialogTrigger asChild>
              <Button className="rounded-full px-6 h-12 bg-primary hover:bg-primary/90 shadow-lg shadow-primary/20">
                <MessageSquare className="w-4 h-4 mr-2" /> Share Your Experience
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[500px] rounded-3xl">
              <DialogHeader>
                <DialogTitle>Report Safety Experience</DialogTitle>
                <CardDescription>Your insights help other women travel safely in TN.</CardDescription>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4 pt-4">
                <div className="space-y-2">
                  <label className="text-sm font-bold">Location in Tamil Nadu</label>
                  <Input 
                    placeholder="e.g., T. Nagar, Chennai" 
                    value={newReport.location}
                    onChange={(e) => setNewReport({...newReport, location: e.target.value})}
                    className="rounded-xl"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-bold">Your Experience</label>
                  <Textarea 
                    placeholder="Describe your safety experience here..." 
                    value={newReport.experience}
                    onChange={(e) => setNewReport({...newReport, experience: e.target.value})}
                    className="min-h-[120px] rounded-xl"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-bold">Safety Level</label>
                  <div className="grid grid-cols-3 gap-2">
                    <Button 
                      type="button" 
                      variant={newReport.type === 'safe' ? 'default' : 'outline'}
                      className={`rounded-xl h-10 ${newReport.type === 'safe' ? 'bg-green-600' : ''}`}
                      onClick={() => setNewReport({...newReport, type: 'safe'})}
                    >
                      <ShieldCheck className="w-4 h-4 mr-2" /> Safe
                    </Button>
                    <Button 
                      type="button" 
                      variant={newReport.type === 'info' ? 'default' : 'outline'}
                      className={`rounded-xl h-10 ${newReport.type === 'info' ? 'bg-blue-600' : ''}`}
                      onClick={() => setNewReport({...newReport, type: 'info'})}
                    >
                      <User className="w-4 h-4 mr-2" /> Info
                    </Button>
                    <Button 
                      type="button" 
                      variant={newReport.type === 'warning' ? 'default' : 'outline'}
                      className={`rounded-xl h-10 ${newReport.type === 'warning' ? 'bg-orange-600' : ''}`}
                      onClick={() => setNewReport({...newReport, type: 'warning'})}
                    >
                      <AlertTriangle className="w-4 h-4 mr-2" /> Alert
                    </Button>
                  </div>
                </div>
                <Button type="submit" className="w-full h-12 rounded-xl mt-4 font-bold">
                  Post Experience
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </header>

        <div className="space-y-6">
          {reports.map((report) => (
            <Card key={report.id} className="border-none shadow-sm hover:shadow-md transition-all overflow-hidden bg-white group">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <Avatar className="w-10 h-10 shrink-0 border border-border">
                    <AvatarFallback className="bg-slate-100 text-slate-600 font-bold">
                      {report.user[0]}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 space-y-2">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-1">
                      <div>
                        <h3 className="font-bold text-foreground">{report.user}</h3>
                        <div className="flex items-center text-muted-foreground text-xs font-medium">
                          <MapPin className="w-3 h-3 mr-1" /> {report.location}
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-[10px] text-muted-foreground font-medium">{report.time}</span>
                        {report.type === 'safe' && <Badge className="bg-green-100 text-green-700 hover:bg-green-100 border-none">Safe Zone</Badge>}
                        {report.type === 'warning' && <Badge className="bg-orange-100 text-orange-700 hover:bg-orange-100 border-none">Stay Alert</Badge>}
                        {report.type === 'info' && <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100 border-none">Travel Tip</Badge>}
                      </div>
                    </div>
                    <p className="text-sm leading-relaxed text-foreground/80 bg-slate-50/50 p-4 rounded-2xl border border-slate-100 italic">
                      "{report.experience}"
                    </p>
                    <div className="flex items-center gap-4 pt-2">
                      <Button variant="ghost" size="sm" className="h-8 text-muted-foreground hover:text-primary gap-1.5 rounded-full px-3">
                        <ThumbsUp className="w-4 h-4" /> Helpful
                      </Button>
                      <Button variant="ghost" size="sm" className="h-8 text-muted-foreground hover:text-primary gap-1.5 rounded-full px-3">
                        <MessageSquare className="w-4 h-4" /> Comment
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <section className="bg-indigo-600 rounded-3xl p-8 text-white flex flex-col md:flex-row items-center gap-8 shadow-xl shadow-indigo-200">
          <div className="w-20 h-20 bg-white/20 rounded-2xl flex items-center justify-center shrink-0">
            <Users className="w-10 h-10" />
          </div>
          <div className="space-y-2 text-center md:text-left">
            <h2 className="text-2xl font-bold">Why share your experience?</h2>
            <p className="text-indigo-100 text-sm max-w-md">
              Your reports help other women make safer travel decisions across Tamil Nadu. By sharing, you're contributing to a safer environment for everyone.
            </p>
          </div>
          <div className="md:ml-auto">
             <Button variant="secondary" className="rounded-full px-8 h-12 font-bold bg-white text-indigo-600 hover:bg-indigo-50" onClick={() => setIsDialogOpen(true)}>
               Add Report
             </Button>
          </div>
        </section>
      </main>
    </div>
  )
}
