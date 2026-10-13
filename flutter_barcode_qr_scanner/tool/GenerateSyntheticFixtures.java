import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.common.BitMatrix;

import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

/** Generates the versioned, non-personal Phase 2 physical-test fixtures. */
public final class GenerateSyntheticFixtures {
    private GenerateSyntheticFixtures() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected one output directory");
        }

        File output = new File(args[0]);
        if (!output.isDirectory() && !output.mkdirs()) {
            throw new IllegalStateException("Could not create output directory");
        }

        write(output, "qr.png", "ADAIRE-P2-QR-001", BarcodeFormat.QR_CODE, 640, 640);
        write(output, "ean13.png", "5901234123457", BarcodeFormat.EAN_13, 960, 480);
        write(output, "code128.png", "ADAIRE-P2-C128-001", BarcodeFormat.CODE_128, 1200, 480);
    }

    private static void write(
        File output,
        String name,
        String value,
        BarcodeFormat format,
        int width,
        int height
    ) throws Exception {
        BitMatrix matrix = new MultiFormatWriter().encode(value, format, width, height);
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                image.setRGB(x, y, matrix.get(x, y) ? 0x000000 : 0xFFFFFF);
            }
        }
        ImageIO.write(image, "png", new File(output, name));
    }
}
