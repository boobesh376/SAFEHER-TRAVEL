'use server';

/**
 * @fileOverview This file defines a Genkit flow for suggesting nearby hotels in Tamil Nadu based on location and safety, using Google review data.
 *
 * - suggestSafeHotels - A function that takes location information and returns a list of suggested hotels.
 * - HotelSuggestionsInput - The input type for the suggestSafeHotels function.
 * - HotelSuggestionsOutput - The return type for the suggestSafeHotels function.
 */

import {ai} from '@/ai/genkit';
import {z} from 'genkit';

const HotelSuggestionsInputSchema = z.object({
  latitude: z.number().describe('The latitude of the user.'),
  longitude: z.number().describe('The longitude of the user.'),
  safetyConcerns: z.string().describe('Any specific safety concerns the user has.'),
});
export type HotelSuggestionsInput = z.infer<typeof HotelSuggestionsInputSchema>;

const HotelSuggestionSchema = z.object({
  name: z.string().describe('The name of the hotel.'),
  address: z.string().describe('The address of the hotel.'),
  googleReviewsSummary: z.string().describe('A summary of Google reviews for the hotel, focusing on safety and cleanliness.'),
  safetyScore: z.number().describe('A score from 1-10 indicating the safety of the hotel, based on reviews and location.'),
  priceRange: z.string().describe('The price range of the hotel (e.g., $, $$, $$$).'),
});

const HotelSuggestionsOutputSchema = z.object({
  suggestions: z.array(HotelSuggestionSchema).describe('A list of suggested hotels.'),
});
export type HotelSuggestionsOutput = z.infer<typeof HotelSuggestionsOutputSchema>;

export async function suggestSafeHotels(input: HotelSuggestionsInput): Promise<HotelSuggestionsOutput> {
  return hotelSuggestionsFlow(input);
}

const hotelSuggestionsPrompt = ai.definePrompt({
  name: 'hotelSuggestionsPrompt',
  input: {schema: HotelSuggestionsInputSchema},
  output: {schema: HotelSuggestionsOutputSchema},
  prompt: `You are a safety-conscious travel assistant specializing in Tamil Nadu, India. A user is in distress and needs a safe hotel recommendation in the region.
Based on the user's current location (latitude: {{{latitude}}}, longitude: {{{longitude}}}) and any specific safety concerns they have ({{{safetyConcerns}}}), suggest a few reputable hotels in Tamil Nadu.

Consider these factors when selecting hotels:
*   Proximity to the user's location within Tamil Nadu.
*   Positive Google reviews, particularly regarding safety, security, and cleanliness in the TN context.
*   Hotel safety scores from reputable sources. You should only suggest hotels that score 7 or higher.
*   Price range appropriate for someone in an emergency situation.

Make sure the Google review summary focuses on the most recent reviews and extracts any mentions of the hotel's safety and security.
Remember to only suggest registered hotels, never suggest other types of establishments such as hostels or motels.`,
  config: {
    safetySettings: [
      {
        category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
        threshold: 'BLOCK_ONLY_HIGH',
      },
      {
        category: 'HARM_CATEGORY_HARASSMENT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE',
      },
    ],
  }
});

const hotelSuggestionsFlow = ai.defineFlow(
  {
    name: 'hotelSuggestionsFlow',
    inputSchema: HotelSuggestionsInputSchema,
    outputSchema: HotelSuggestionsOutputSchema,
  },
  async input => {
    const {output} = await hotelSuggestionsPrompt(input);
    return output!;
  }
);
