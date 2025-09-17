// src/geo/geo.controller.ts
import { Controller, Get, Query, HttpException, HttpStatus } from '@nestjs/common';
import fetch from 'node-fetch';

@Controller('geo')
export class GeoController {
  private base = 'https://nominatim.openstreetmap.org';

  private async safeJson(res: any) {
    const ct = (res.headers.get('content-type') || '').toLowerCase();
    // если это явно JSON — парсим как JSON
    if (ct.includes('application/json')) return res.json();
    // иначе читаем как текст и бросаем понятную ошибку
    const text = await res.text();
    throw new HttpException(
      {
        message: 'Geo provider returned non-JSON',
        statusCode: HttpStatus.BAD_GATEWAY,
        providerStatus: res.status,
        contentType: ct,
        bodyPreview: text.slice(0, 500),
      },
      HttpStatus.BAD_GATEWAY,
    );
  }

  @Get('search')
  async search(@Query('q') q: string, @Query('limit') limit = '8', @Query('lang') lang = 'ru') {
    if (!q || q.trim().length < 2) return [];
    const url = `${this.base}/search?format=jsonv2&addressdetails=1&limit=${limit}&accept-language=${encodeURIComponent(
      lang,
    )}&q=${encodeURIComponent(q)}`;

    const res = await fetch(url, {
      headers: {
        // Укажите свой email/сайт (требование Nominatim)
        'User-Agent': 'EventHub/1.0 (support@eventhub.local)',
        Accept: 'application/json',
      },
    });

    if (!res.ok) {
      // читаем как текст (на случай HTML)
      const text = await res.text();
      throw new HttpException(
        { message: 'Geo provider error', providerStatus: res.status, bodyPreview: text.slice(0, 500) },
        HttpStatus.BAD_GATEWAY,
      );
    }

    const data = (await this.safeJson(res)) as any[];

    return data.map((i: any) => ({
      label: i.display_name as string,
      lat: parseFloat(i.lat),
      lon: parseFloat(i.lon),
      city:
        i.address?.city ||
        i.address?.town ||
        i.address?.village ||
        i.address?.municipality ||
        i.address?.state_district ||
        i.address?.state ||
        '',
      address: i.display_name as string,
    }));
  }

  @Get('reverse')
  async reverse(@Query('lat') lat: string, @Query('lon') lon: string, @Query('lang') lang = 'ru') {
    const url = `${this.base}/reverse?format=jsonv2&addressdetails=1&accept-language=${encodeURIComponent(
      lang,
    )}&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}`;

    const res = await fetch(url, {
      headers: {
        'User-Agent': 'EventHub/1.0 (support@eventhub.local)',
        Accept: 'application/json',
      },
    });

    if (!res.ok) {
      const text = await res.text();
      throw new HttpException(
        { message: 'Geo provider error', providerStatus: res.status, bodyPreview: text.slice(0, 500) },
        HttpStatus.BAD_GATEWAY,
      );
    }

    const j = (await this.safeJson(res)) as any;
    const addr = j.address || {};
    return {
      label: j.display_name as string,
      city:
        addr.city ||
        addr.town ||
        addr.village ||
        addr.municipality ||
        addr.state_district ||
        addr.state ||
        '',
      address: j.display_name as string,
      lat: parseFloat(lat),
      lon: parseFloat(lon),
    };
  }
}
