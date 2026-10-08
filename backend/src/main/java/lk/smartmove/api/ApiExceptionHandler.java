package lk.smartmove.api;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RestControllerAdvice
public class ApiExceptionHandler {
    private static final Pattern REPORT_ERROR = Pattern.compile("ORA-200(04|05|10|11):");

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<Map<String, String>> handleRequest(ResponseStatusException exception) {
        return ResponseEntity.status(exception.getStatusCode())
                .body(Map.of("error", exception.getReason() == null ? "Request failed" : exception.getReason()));
    }

    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<Map<String, String>> handleDatabase(DataAccessException exception) {
        String detail = exception.getMostSpecificCause().getMessage();
        if (detail == null || detail.isBlank()) {
            detail = exception.getMessage() == null ? "No database error details available" : exception.getMessage();
        }
        Matcher reportError = REPORT_ERROR.matcher(detail);
        if (reportError.find()) {
            boolean passengerNotFound = "05".equals(reportError.group(1));
            HttpStatus status = passengerNotFound ? HttpStatus.NOT_FOUND : HttpStatus.BAD_REQUEST;
            String error = passengerNotFound ? "Passenger does not exist" : "Invalid report parameters";
            return ResponseEntity.status(status).body(Map.of("error", error, "detail", detail));
        }
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Oracle database operation failed", "detail",
                        detail));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<Map<String, String>> handleUploadSize(MaxUploadSizeExceededException exception) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                .body(Map.of("error", "Vehicle image must be 8 MB or smaller"));
    }
}
