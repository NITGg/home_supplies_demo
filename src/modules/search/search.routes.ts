import { Router } from "express";
import { globalSearch } from "./search.controller";

const searchRouter = Router();

searchRouter.get("/", globalSearch);

export default searchRouter;
