"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeoController = void 0;
const common_1 = require("@nestjs/common");
const node_fetch_1 = __importDefault(require("node-fetch"));
let GeoController = class GeoController {
    constructor() {
        this.base = 'https://nominatim.openstreetmap.org';
    }
    async safeJson(res) {
        const ct = (res.headers.get('content-type') || '').toLowerCase();
        if (ct.includes('application/json'))
            return res.json();
        const text = await res.text();
        throw new common_1.HttpException({
            message: 'Geo provider returned non-JSON',
            statusCode: common_1.HttpStatus.BAD_GATEWAY,
            providerStatus: res.status,
            contentType: ct,
            bodyPreview: text.slice(0, 500),
        }, common_1.HttpStatus.BAD_GATEWAY);
    }
    async search(q, limit = '8', lang = 'ru') {
        if (!q || q.trim().length < 2)
            return [];
        const url = `${this.base}/search?format=jsonv2&addressdetails=1&limit=${limit}&accept-language=${encodeURIComponent(lang)}&q=${encodeURIComponent(q)}`;
        const res = await (0, node_fetch_1.default)(url, {
            headers: {
                'User-Agent': 'EventHub/1.0 (support@eventhub.local)',
                Accept: 'application/json',
            },
        });
        if (!res.ok) {
            const text = await res.text();
            throw new common_1.HttpException({ message: 'Geo provider error', providerStatus: res.status, bodyPreview: text.slice(0, 500) }, common_1.HttpStatus.BAD_GATEWAY);
        }
        const data = (await this.safeJson(res));
        return data.map((i) => {
            var _a, _b, _c, _d, _e, _f;
            return ({
                label: i.display_name,
                lat: parseFloat(i.lat),
                lon: parseFloat(i.lon),
                city: ((_a = i.address) === null || _a === void 0 ? void 0 : _a.city) ||
                    ((_b = i.address) === null || _b === void 0 ? void 0 : _b.town) ||
                    ((_c = i.address) === null || _c === void 0 ? void 0 : _c.village) ||
                    ((_d = i.address) === null || _d === void 0 ? void 0 : _d.municipality) ||
                    ((_e = i.address) === null || _e === void 0 ? void 0 : _e.state_district) ||
                    ((_f = i.address) === null || _f === void 0 ? void 0 : _f.state) ||
                    '',
                address: i.display_name,
            });
        });
    }
    async reverse(lat, lon, lang = 'ru') {
        const url = `${this.base}/reverse?format=jsonv2&addressdetails=1&accept-language=${encodeURIComponent(lang)}&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}`;
        const res = await (0, node_fetch_1.default)(url, {
            headers: {
                'User-Agent': 'EventHub/1.0 (support@eventhub.local)',
                Accept: 'application/json',
            },
        });
        if (!res.ok) {
            const text = await res.text();
            throw new common_1.HttpException({ message: 'Geo provider error', providerStatus: res.status, bodyPreview: text.slice(0, 500) }, common_1.HttpStatus.BAD_GATEWAY);
        }
        const j = (await this.safeJson(res));
        const addr = j.address || {};
        return {
            label: j.display_name,
            city: addr.city ||
                addr.town ||
                addr.village ||
                addr.municipality ||
                addr.state_district ||
                addr.state ||
                '',
            address: j.display_name,
            lat: parseFloat(lat),
            lon: parseFloat(lon),
        };
    }
};
exports.GeoController = GeoController;
__decorate([
    (0, common_1.Get)('search'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('lang')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], GeoController.prototype, "search", null);
__decorate([
    (0, common_1.Get)('reverse'),
    __param(0, (0, common_1.Query)('lat')),
    __param(1, (0, common_1.Query)('lon')),
    __param(2, (0, common_1.Query)('lang')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], GeoController.prototype, "reverse", null);
exports.GeoController = GeoController = __decorate([
    (0, common_1.Controller)('geo')
], GeoController);
//# sourceMappingURL=geo.controller.js.map