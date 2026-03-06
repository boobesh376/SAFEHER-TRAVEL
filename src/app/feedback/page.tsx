"use client"

import { Navigation } from "@/components/Navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Star, Send, ThumbsUp, ChevronLeft, Heart } from "lucide-react"
import Link from "next/link"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"

export default function FeedbackPage() {
  const [submitted, setSubmitted] = useState(false)
  const { toast } = useToast()

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitted(true)
    toast({
      title: "Thank You!",
      description: "Your feedback helps us make the world safer.",
    })
  }

  if (submitted) {
    return (
      <div className="min-h-screen md:pl-20 bg-slate-50 flex items-center justify-center p-6">
        <Navigation />
        <Card className="max-w-md w-full border-none shadow-xl text-center p-8 space-y-6 animate-in zoom-in-95 duration-500">
          <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center text-green-600 mx-auto">
            <ThumbsUp className="w-10 h-10" />
          </div>
          <div className="space-y-2">
            <h1 className="text-3xl font-black">Feedback Received</h1>
            <p className="text-muted-foreground">
              Your insights are vital to our mission of providing safety for everyone traveling.
            </p>
          </div>
          <Button asChild className="w-full h-12 rounded-full">
            <Link href="/">Back to Dashboard</Link>
          </Button>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen md:pl-20 bg-slate-50 pb-20">
      <Navigation />
      <main className="max-w-2xl mx-auto p-6 space-y-8">
        <header className="space-y-2">
          <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground">
            <ChevronLeft className="w-5 h-5 mr-1" /> Dashboard
          </Link>
          <h1 className="text-3xl font-bold font-headline">App Feedback</h1>
          <p className="text-muted-foreground">How was your experience with Safe Her Travel?</p>
        </header>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Card className="border-none shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">Overall Experience</CardTitle>
              <CardDescription>Rate your overall satisfaction with the app's performance.</CardDescription>
            </CardHeader>
            <CardContent>
              <RadioGroup defaultValue="4" className="flex justify-between md:justify-start md:gap-8">
                {[1, 2, 3, 4, 5].map((val) => (
                  <div key={val} className="flex flex-col items-center gap-2">
                    <RadioGroupItem value={val.toString()} id={`r${val}`} className="peer sr-only" />
                    <Label
                      htmlFor={`r${val}`}
                      className="w-12 h-12 rounded-full border border-border flex items-center justify-center cursor-pointer transition-all peer-data-[state=checked]:bg-primary peer-data-[state=checked]:text-white peer-data-[state=checked]:border-primary hover:border-primary/50"
                    >
                      {val}
                    </Label>
                  </div>
                ))}
              </RadioGroup>
            </CardContent>
          </Card>

          <Card className="border-none shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">Which features did you find most helpful?</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {['SOS Signal', 'Chatbot Assistance', 'Hotel Suggestions', 'Nearby Resources', 'Live Location'].map((feature) => (
                  <label key={feature} className="flex items-center gap-3 p-3 rounded-lg border border-border hover:bg-slate-50 cursor-pointer transition-colors has-[:checked]:bg-primary/10 has-[:checked]:border-primary/30">
                    <input type="checkbox" className="w-5 h-5 accent-primary" />
                    <span className="text-sm font-medium">{feature}</span>
                  </label>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card className="border-none shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">Any suggestions for improvement?</CardTitle>
            </CardHeader>
            <CardContent>
              <Textarea 
                placeholder="Share your thoughts on how we can make you feel safer..." 
                className="min-h-[120px] bg-slate-50 border-none rounded-xl"
              />
            </CardContent>
          </Card>

          <Button type="submit" className="w-full h-14 rounded-full text-lg font-bold bg-primary shadow-lg shadow-primary/20 hover:scale-[1.02] active:scale-[0.98] transition-all">
            <Send className="w-5 h-5 mr-2" /> Submit Feedback
          </Button>
          
          <div className="flex items-center justify-center gap-2 text-muted-foreground text-sm font-medium py-4">
            <Heart className="w-4 h-4 text-red-400 fill-red-400" />
            Together, we keep each other safe.
          </div>
        </form>
      </main>
    </div>
  )
}
