export interface ArticleItem {
  id: number;
  title: string;
  slug: string;
  summary: string;
  content: string;
  cover_image: string | null;
  keywords: string;
  published_at: string | null;
  created_at: string;
  updated_at: string;
  author: string;
  sort_id: number;
}

export interface ArticleFilter {
  id?: string;
  title?: string;
  summary?: string;
  content?: string;
  slug?: string;
  created_from?: string;
  created_to?: string;
  updated_from?: string;
  updated_to?: string;
}

export interface PaginatedArticleResponse {
  totalArticles: number;
  totalPages: number;
  articles: ArticleItem[];
}

export interface CreateArticlePayload {
  title: string;
  summary: string;
  content: string;
  keywords: string;
  published_at: string;
  author: string;
  cover_image: File | null;
}

export interface UpdateArticlePayload {
  title?: string;
  summary?: string;
  content?: string;
  keywords?: string;
  published_at?: string;
  author?: string;
  cover_image?: File | null;
}
