FROM ghcr.io/cirruslabs/flutter:3.27.3

WORKDIR /app

COPY pubspec.* ./

RUN flutter pub get

COPY . .

RUN flutter build apk --release

CMD ["cp", "build/app/outputs/flutter-apk/app-release.apk", "/output/app-release.apk"]OPY --from=build /app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
