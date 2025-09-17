export declare class GeoController {
    private base;
    private safeJson;
    search(q: string, limit?: string, lang?: string): Promise<{
        label: string;
        lat: number;
        lon: number;
        city: any;
        address: string;
    }[]>;
    reverse(lat: string, lon: string, lang?: string): Promise<{
        label: string;
        city: any;
        address: string;
        lat: number;
        lon: number;
    }>;
}
