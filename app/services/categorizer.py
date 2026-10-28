from typing import Optional, Tuple
from app.schemas.expense import ExpenseCategory


CATEGORY_KEYWORDS = {
    ExpenseCategory.FOOD: [
        "restaurant", "cafe", "coffee", "dhaba", "hotel", "bakery", "bakers",
        "grocery", "supermarket", "mart", "store", "food", "dining", "lunch",
        "dinner", "breakfast", "burger", "pizza", "biryani", "karahi", "tikka",
        "bbq", "sweets", "naan", "chai", "tea", "mcdonald", "kfc", "subway",
        "hardees", "dominos", "cheezious", "imtiaz", "carrefour", "al-fatah",
        "metro", "hyperstar", "meat", "vegetable", "fruits", "milk", "dairy"
    ],
    ExpenseCategory.TRANSPORT: [
        "fuel", "petrol", "cng", "diesel", "shell", "total", "pso", "attock",
        "hascol", "uber", "careem", "indrive", "bykea", "taxi", "cab", "rickshaw",
        "metro bus", "speedo", "toll", "plaza", "motorway", "puncture", "mechanic",
        "oil change", "tuning", "car wash", "tyre", "tire", "parking"
    ],
    ExpenseCategory.BILLS: [
        "electricity", "power", "lesco", "kelectric", "iesco", "gepco", "mepco",
        "pesco", "hesco", "fesco", "qesco", "gas", "sngpl", "ssgc", "water",
        "wasa", "internet", "wifi", "broadband", "fiber", "ptcl", "stormfiber",
        "nayatel", "transworld", "mobile", "postpaid", "prepaid", "jazz",
        "telenor", "zong", "ufone", "bill", "utility"
    ],
    ExpenseCategory.HEALTHCARE: [
        "pharmacy", "medical", "chemist", "medicine", "drugs", "clinic",
        "hospital", "doctor", "dentist", "dental", "physician", "consultation",
        "laboratory", "chughtai", "shaukat khanum", "agha khan", "excel labs",
        "test", "blood", "x-ray", "ultrasound", "scan", "prescription", "dawa"
    ],
    ExpenseCategory.SHOPPING: [
        "clothing", "apparel", "shoes", "garments", "boutique", "mall",
        "khaadi", "outfitters", "sapphire", "gul ahmed", "junaid jamshed",
        "j.", "bonanza", "alkaram", "limelight", "edenrobe", "service", "bata",
        "ndure", "borjan", "electronics", "haier", "dawlance", "gree", "pel",
        "daraz", "amazon", "retail", "fashion", "cosmetics"
    ],
    ExpenseCategory.EDUCATION: [
        "school", "college", "university", "academy", "tuition", "coaching",
        "fee", "books", "stationery", "notebook", "pen", "pencil", "library",
        "course", "exam", "admission", "semester", "lums", "nust", "fast",
        "iba", "punjab university"
    ],
    ExpenseCategory.ENTERTAINMENT: [
        "cinema", "movie", "theatre", "imax", "cinepax", "cue", "universal",
        "netflix", "spotify", "youtube", "gaming", "steam", "playstation",
        "bowling", "amusement", "joyland", "park", "zoo", "concert", "match",
        "ticket"
    ],
    ExpenseCategory.RENT: [
        "rent", "landlord", "tenant", "lease", "apartment rent", "house rent",
        "office rent", "shop rent", "maintenance fee", "society dues"
    ],
    ExpenseCategory.TRAVEL: [
        "airline", "flight", "pia", "airblue", "serene", "fly jinnah", "emirates",
        "ticket", "railway", "train", "pakistan railways", "daewoo", "faisal movers",
        "road prince", "hotel", "resort", "booking.com", "airbnb", "visa",
        "luggage", "tour", "tourism"
    ]
}


class SmartCategorizer:
    """
    Deterministic rule-based category classifier that maps merchant names,
    receipt titles, and OCR keywords to canonical ExpenseCategory values.
    Can be used standalone or as a fallback when AI confidence is low.
    """

    @classmethod
    def suggest_category(
        cls,
        merchant_name: Optional[str] = None,
        raw_text: Optional[str] = None,
        line_items_text: Optional[str] = None
    ) -> Tuple[ExpenseCategory, str]:
        """
        Analyzes available text fields and returns a suggested ExpenseCategory
        along with an explanation string.
        """
        combined_text = " ".join(
            filter(None, [merchant_name, raw_text, line_items_text])
        ).lower()

        if not combined_text.strip():
            return (
                ExpenseCategory.OTHER,
                "No merchant name or receipt details available for automated categorization."
            )

        # Score categories by keyword matches
        scores = {cat: 0 for cat in CATEGORY_KEYWORDS}
        matched_words = {cat: [] for cat in CATEGORY_KEYWORDS}

        # Higher weight given to matches in merchant_name
        merchant_clean = (merchant_name or "").lower()

        for category, keywords in CATEGORY_KEYWORDS.items():
            for kw in keywords:
                # Check merchant name (3x weight)
                if kw in merchant_clean:
                    scores[category] += 3
                    if kw not in matched_words[category]:
                        matched_words[category].append(kw)
                # Check overall receipt text (1x weight)
                elif kw in combined_text:
                    scores[category] += 1
                    if kw not in matched_words[category]:
                        matched_words[category].append(kw)

        # Find best category
        best_category = max(scores, key=scores.get)
        highest_score = scores[best_category]

        if highest_score > 0:
            matching_terms = ", ".join(matched_words[best_category][:3])
            explanation = (
                f"Suggested as {best_category.value} based on identified terms: '{matching_terms}'"
            )
            return (best_category, explanation)

        return (
            ExpenseCategory.OTHER,
            "Could not confidently match receipt to a specific category. Classified as Other."
        )
