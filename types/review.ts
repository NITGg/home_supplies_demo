export interface Review {
  id: number;
  courier_id: number;
  customer_id: number;
  order_id: number;
  rating: number;
  comment: string;
  created_at: string;
  updated_at: string;
}

export interface ReviewWithDetails extends Review {
  courier: {
    id: number;
    user: {
      id: number;
      full_name: string;
      phone: string;
    };
  };
  customer: {
    id: number;
    full_name: string;
    phone: string;
  };
  order: {
    id: number;
    order_number: string;
    status: string;
  };
}

export interface ReviewFilter {
  id: string;
  courier_id: string;
  customer_id: string;
  order_id: string;
  rating: string;
  comment: string;
  created_atFrom: string;
  created_atTo: string;
  updated_atFrom: string;
  updated_atTo: string;
}

export interface PaginatedReviewsResponse {
  totalReviews: number;
  totalPages: number;
  reviews: Review[];
}

export interface ReviewDetailsResponse {
  review: ReviewWithDetails;
}
