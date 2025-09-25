import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  ValidationPipe,
} from "@nestjs/common";

import { JwtAuthGuard } from "../auth/jwt.guard";
import { UsersService } from "./users.service";
import {
  ConfirmEmailChangeDto,
  RequestEmailChangeDto,
  ReviewsFilterDto,
  UpdateProfileDto,
  UserEventsFilterDto,
  UpdateCategoryPreferencesDto,
  ChangePasswordDto,
  DeleteAccountDto,
} from "./dto";
import { Public } from "../auth/public.decorator";

@Controller("users")
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get("me")
  me(@Req() req: any) {
    return this.users.me(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch("me")
  update(@Req() req: any, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(req.user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get("me/categories")
  myCategories(@Req() req: any) {
    return this.users.getCategoryPreferences(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch("me/categories")
  updateCategories(
    @Req() req: any,
    @Body(new ValidationPipe({ transform: true })) dto: UpdateCategoryPreferencesDto,
  ) {
    return this.users.updateCategoryPreferences(req.user.sub, dto.categories);
  }

  @UseGuards(JwtAuthGuard)
  @Patch("me/password")
  changePassword(@Req() req: any, @Body() dto: ChangePasswordDto) {
    return this.users.changePassword(req.user.sub, dto.currentPassword, dto.newPassword);
  }

  @UseGuards(JwtAuthGuard)
  @Post("me/delete")
  deleteAccount(@Req() req: any, @Body() dto: DeleteAccountDto) {
    return this.users.deleteAccount(req.user.sub, dto.password);
  }

  @UseGuards(JwtAuthGuard)
  @Post("me/email-request")
  requestEmail(@Req() req: any, @Body() dto: RequestEmailChangeDto) {
    return this.users.requestEmailChange(req.user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post("me/email-confirm")
  confirmEmail(@Req() req: any, @Body() dto: ConfirmEmailChangeDto) {
    return this.users.confirmEmailChange(req.user.sub, dto);
  }

  @Get(":id/public")
  publicProfile(@Param("id") id: string, @Req() req: any) {
    const viewerId = req.user?.sub;
    return this.users.profile(id, { viewerId });
  }

  @Public()
  @Get("search")
  search(@Query("q") q?: string, @Query("limit") limit = "10") {
    return this.users.search(q ?? "", Number(limit) || 10);
  }

  @Get(":id/reviews")
  reviews(
    @Param("id") id: string,
    @Query(new ValidationPipe({ transform: true })) query: ReviewsFilterDto,
  ) {
    return this.users.reviews(id, query);
  }

  @Get(":id/events")
  events(@Param("id") id: string, @Query() query: UserEventsFilterDto) {
    return this.users.eventsCreated(id, query);
  }
}
