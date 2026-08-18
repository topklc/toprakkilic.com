<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Files</title>
    <link rel="stylesheet" href="../style.css">
</head>
<body>
    <div class="introduction">
        <h1><a href="../index.html" class="subs">Toprak Kilic</a></h1>
        <?php
            $dir = '../files/';
            echo '<h3>Index of '. $dir .'</h3>';
        ?>
        <hr>
    </div>
    <div class="files">
            <?php
            // lists all files in directory, future recursive support.
            $dir = '../files/';
            $files = array_diff(scandir($dir), ['.', '..', basename(__FILE__)]);
            natsort($files);
            foreach ($files as $file) {
                echo '<a href="' . $dir . htmlspecialchars($file) . '">' . htmlspecialchars($file) . '</a><br>';
            }
        ?>
    </div>
    <div class="copyright">
        <hr>
        <p>© 2026 Toprak Kilic, all rights reserved.</p>
    </div>
</body>
</html>