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
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeleteAccountDto = exports.ChangePasswordDto = exports.UpdateCategoryPreferencesDto = exports.UserEventsFilterDto = exports.ReviewsFilterDto = exports.ConfirmEmailChangeDto = exports.RequestEmailChangeDto = exports.UpdateProfileDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class UpdateProfileDto {
}
exports.UpdateProfileDto = UpdateProfileDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "firstName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "lastName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "avatarUrl", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "bio", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "birthDate", void 0);
class RequestEmailChangeDto {
}
exports.RequestEmailChangeDto = RequestEmailChangeDto;
__decorate([
    (0, class_validator_1.IsNotEmpty)(),
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], RequestEmailChangeDto.prototype, "newEmail", void 0);
__decorate([
    (0, class_validator_1.IsNotEmpty)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RequestEmailChangeDto.prototype, "password", void 0);
class ConfirmEmailChangeDto {
}
exports.ConfirmEmailChangeDto = ConfirmEmailChangeDto;
__decorate([
    (0, class_validator_1.IsNotEmpty)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ConfirmEmailChangeDto.prototype, "code", void 0);
class ReviewsFilterDto {
}
exports.ReviewsFilterDto = ReviewsFilterDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(5),
    __metadata("design:type", Number)
], ReviewsFilterDto.prototype, "rating", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['event', 'participant']),
    __metadata("design:type", String)
], ReviewsFilterDto.prototype, "type", void 0);
class UserEventsFilterDto {
}
exports.UserEventsFilterDto = UserEventsFilterDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['all', 'upcoming', 'past']),
    __metadata("design:type", String)
], UserEventsFilterDto.prototype, "filter", void 0);
class UpdateCategoryPreferencesDto {
}
exports.UpdateCategoryPreferencesDto = UpdateCategoryPreferencesDto;
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(5),
    (0, class_validator_1.ArrayMaxSize)(5),
    (0, class_validator_1.ArrayUnique)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], UpdateCategoryPreferencesDto.prototype, "categories", void 0);
class ChangePasswordDto {
}
exports.ChangePasswordDto = ChangePasswordDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], ChangePasswordDto.prototype, "currentPassword", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], ChangePasswordDto.prototype, "newPassword", void 0);
class DeleteAccountDto {
}
exports.DeleteAccountDto = DeleteAccountDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], DeleteAccountDto.prototype, "password", void 0);
//# sourceMappingURL=dto.js.map