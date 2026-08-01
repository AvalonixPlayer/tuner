FROM ghcr.io/cirruslabs/flutter:3.41.9

WORKDIR /app

COPY pubspec.* ./

RUN flutter pub get

COPY . .

RUN chmod +x android/gradlew

RUN flutter build apk --release

CMD ["cp", "build/app/outputs/flutter-apk/app-release.apk", "/output/app-release.apk"]OPY --from=build /app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
