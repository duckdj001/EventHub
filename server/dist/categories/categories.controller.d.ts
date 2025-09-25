import { PrismaService } from '../common/prisma.service';
export declare class CategoriesController {
    private prisma;
    constructor(prisma: PrismaService);
    list(): Promise<{
        id: string;
        name: string;
        parentId: string | null;
        isSuggested: boolean;
    }[]>;
}
