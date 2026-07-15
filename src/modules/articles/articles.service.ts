import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateArticleInput,
  UpdateArticleInput,
  DeleteArticlesInput,
} from "./articles.schema";
import { slugifyTitle } from "@/lib/slugify";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";

async function ensureUniqueSlug(baseSlug: string, excludeId?: number) {
  let slug = baseSlug;
  let i = 2;

  while (true) {
    const exists = await prisma.article.findFirst({
      where: {
        slug,
        ...(excludeId ? { id: { not: excludeId } } : {}),
      },
      select: { id: true },
    });

    if (!exists) return slug;
    slug = `${baseSlug}-${i++}`;
  }
}

export async function listArticlesService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalArticles, articles] = await prisma.$transaction([
    prisma.article.count({ where: data.where as any }),
    prisma.article.findMany(data as any),
  ]);

  return {
    totalArticles,
    totalPages: Math.ceil(totalArticles / take),
    articles,
  };
}

export async function getArticleByIdService(input: { id: number }) {
  const article = await prisma.article.findUnique({
    where: { id: input.id },
  });
  if (!article) throw new HttpError(404, "articles:errors.not_found");
  return article;
}

export async function getArticleBySlugService(input: { slug: string }) {
  const article = await prisma.article.findUnique({
    where: { slug: input.slug, is_active: true },
  });
  if (!article) throw new HttpError(404, "articles:errors.not_found");
  return article;
}

export async function createArticleService(input: {
  data: CreateArticleInput;
  file?: Express.Multer.File;
}) {
  const { data, file } = input;

  // cover image upload (optional)
  let cover_image = data.cover_image ?? null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "articles",
    });
    cover_image = secure_url;
  }

  // slug (optional from client, otherwise from title)
  const base = slugifyTitle(data.slug?.trim() ? data.slug : data.title);
  const slug = await ensureUniqueSlug(base);

  return prisma.article.create({
    data: {
      ...data,
      slug,
      cover_image,
    },
  });
}

export async function updateArticleService(input: {
  id: number;
  data: UpdateArticleInput;
  file?: Express.Multer.File;
}) {
  const { id, data, file } = input;

  const current = await prisma.article.findUnique({
    where: { id },
    select: { id: true, title: true, slug: true, cover_image: true },
  });
  if (!current) throw new HttpError(404, "articles:errors.not_found");

  // cover upload (optional) + optional delete old cover
  let nextCover: string | null = null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "articles",
    });
    nextCover = secure_url;
    // Delete old cover from Cloudinary
    if (current.cover_image) {
      const publicId = extractPublicIdFromUrl(current.cover_image);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  }

  // slug logic
  let nextSlug: string | undefined = undefined;

  if (typeof data.slug === "string" && data.slug.trim()) {
    const base = slugifyTitle(data.slug);
    nextSlug = await ensureUniqueSlug(base, id);
  } else if (
    typeof data.title === "string" &&
    data.title.trim() &&
    data.title.trim() !== current.title
  ) {
    const base = slugifyTitle(data.title);
    nextSlug = await ensureUniqueSlug(base, id);
  }

  return prisma.article.update({
    where: { id },
    data: {
      ...data,
      ...(nextSlug ? { slug: nextSlug } : {}),
      ...(nextCover ? { cover_image: nextCover } : {}),
    },
  });
}

export async function deleteArticlesService(input: DeleteArticlesInput) {
  const result = await prisma.article.deleteMany({
    where: { id: { in: input.ids } },
  });
  return { count: result.count };
}

export async function deleteArticleService(input: { id: number }) {
  const exists = await prisma.article.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "articles:errors.not_found");

  await prisma.article.delete({ where: { id: input.id } });
  return { ok: true as const };
}
