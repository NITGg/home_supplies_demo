import multer from "multer";
import { Request } from "express";
import fs from "fs";
import { AppError } from "../../core/errors/app.error";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { FileType, StoreInEnum } from "../../types/global.types";

export const multerUpload = ({
  sendedFileDest = "general",
  sendedFileType = FileType.image,
  storeIn = StoreInEnum.DISK,
}: {
  sendedFileDest?: string;
  sendedFileType?: string[];
  storeIn?: StoreInEnum;
}): multer.Multer => {
  const storage =
    storeIn == StoreInEnum.MEMORY
      ? multer.memoryStorage()
      : multer.diskStorage({
          // destination: (req: any, file, cb) => {
          //   const fullDest = `uploads/${sendedFileDest}/${req.user._id}`;
          //   if (!fs.existsSync(fullDest)) {
          //     fs.mkdirSync(fullDest, { recursive: true });
          //   }
          //   cb(null, fullDest);
          // },
          // filename: (req: any, file, cb) => {
          //   cb(null, `${file.originalname}`);
          // },
        });

  const fileFilter = (
    req: Request,
    file: Express.Multer.File,
    cb: CallableFunction
  ) => {
    if (file.size > 200 * 1024 * 1024 && storeIn == StoreInEnum.MEMORY) {
      return cb(
        new AppError(HttpStatusCode.BAD_REQUEST, "Use disk not memory"),
        false
      );
    } else if (!sendedFileType.includes(file.mimetype)) {
      return cb(
        new AppError(HttpStatusCode.BAD_REQUEST, "Invalid file format"),
        false
      );
    }
    cb(null, true);
  };
  return multer({ storage, fileFilter });
};
