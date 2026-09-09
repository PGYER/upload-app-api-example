package com.pgyer.uploader;

import com.google.gson.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.Map;

public class PollingRegression {
    public static void main(String[] args) throws Exception {
        JsonArray cases = new Gson().fromJson(
                new String(Files.readAllBytes(Paths.get(args[0])), StandardCharsets.UTF_8), JsonArray.class);
        for (JsonElement element : cases) {
            JsonObject test = element.getAsJsonObject();
            JsonArray responses = test.getAsJsonArray("responses");
            int[] calls = {0};
            Exception error = null;
            Map<String, Object> result = null;
            try {
                result = PGYERAppUploader.pollBuildInfo(() -> {
                    int index = calls[0]++;
                    if (test.has("transportError")) throw new java.io.IOException("mock transport failure");
                    if (index >= responses.size()) throw new Exception("Unexpected extra poll");
                    JsonElement response = responses.get(index);
                    return response.isJsonPrimitive() ? response.getAsString() : response.toString();
                }, message -> {});
            } catch (Exception ex) {
                error = ex;
            }
            String name = test.get("name").getAsString();
            if (calls[0] != test.get("requests").getAsInt()) throw new AssertionError(name + ": request count " + calls[0]);
            if (test.has("errorContains")) {
                if (error == null) throw new AssertionError(name + ": expected failure");
                for (JsonElement text : test.getAsJsonArray("errorContains"))
                    if (!error.getMessage().contains(text.getAsString())) throw new AssertionError(name + ": lost original error: " + error);
            } else if (error != null || result == null || !"fixture".equals(result.get("buildKey"))) {
                throw new AssertionError(name + ": expected build info", error);
            }
            System.out.println("PASS Java " + name);
        }
    }
}
