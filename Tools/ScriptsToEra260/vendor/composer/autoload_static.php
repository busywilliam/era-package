<?php

// autoload_static.php @generated by Composer

namespace Composer\Autoload;

class ComposerStaticInitf343c789c3992efd9a00a00cbd22ea08
{
    public static $prefixLengthsPsr4 = array (
        'B' => 
        array (
            'B\\' => 2,
        ),
    );

    public static $prefixDirsPsr4 = array (
        'B\\' => 
        array (
            0 => __DIR__ . '/../..' . '/../../../Soft/Programming/PHP/Projects/B/B/src',
        ),
    );

    public static function getInitializer(ClassLoader $loader)
    {
        return \Closure::bind(function () use ($loader) {
            $loader->prefixLengthsPsr4 = ComposerStaticInitf343c789c3992efd9a00a00cbd22ea08::$prefixLengthsPsr4;
            $loader->prefixDirsPsr4 = ComposerStaticInitf343c789c3992efd9a00a00cbd22ea08::$prefixDirsPsr4;

        }, null, ClassLoader::class);
    }
}
